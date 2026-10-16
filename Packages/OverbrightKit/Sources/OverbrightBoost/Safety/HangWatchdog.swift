// OverbrightBoost/Safety/HangWatchdog.swift — restores the displays when the main thread stalls while scaled.
// ARCHITECTURE.md §4.6, §7.4, §8.1 rules 2 and 4; D7. Thread: its own utility queue (a `DispatchSourceTimer`, the one
// sanctioned repeating timer), never the main actor; it touches displays only through
// `TableWriter.writeBaselines(fromLedger:)` under the ledger lock (`EmergencyRestore`), and never calls
// `DispatchQueue.main.sync`. Owned by WP5 (seeded by WP0a with the §10.0 signatures).
//
// While active (the engine switches it on while any display is scaled or dimmed), the timer sends a ping to the main
// queue every `hangPing` (2 s). A ping still unanswered `hangTimeout` (3 s) after it was sent means the main thread is
// stuck: under the ledger lock the watchdog bumps the hang epoch, writes every ledger baseline and forgets the entries,
// then raises the fired flag and journals `hang.fired`. It fires once per stall; the next pong re-arms it. A stall is
// therefore caught 3–5 s after it starts (3 s when it starts right after a ping, 5 s right before one). The timer wakes
// only at ping times and at one timeout deadline, never in between.
import Dispatch
import Foundation
import OverbrightCore
import os

nonisolated private let log = Log.logger(.engine)

/// Ping-pong with the main thread every 2 s while any display is scaled; a ping unanswered for 3 s bumps the hang
/// epoch and writes every ledger baseline, then records that it fired.
public nonisolated final class HangWatchdog: Sendable {
    /// Everything that changes, behind one lock (never held while the ledger lock is taken).
    struct State {
        var timer: (any DispatchSourceTimer)?
        /// Bumped on every switch, so a tick from an older timer does nothing.
        var generation: UInt64 = 0
        var pingID: UInt64 = 0
        /// Uptime (ns) of the ping that has not been answered yet.
        var pingSentAt: UInt64?
        /// Fired for the current stall: no second restore until a pong arrives.
        var firedForStall = false
        /// Fired since the engine last asked.
        var firedFlag = false
        var fires = 0
        var pongs = 0
        /// Uptime (ns) of the last restore (tests check the 3–5 s window).
        var lastFiredAt: UInt64?
    }

    private let writer: TableWriter
    private let ledger: SafetyLedger
    private let journal: any DiagnosticsJournal
    private let pingInterval: Duration
    private let timeout: Duration
    private let pinged: DispatchQueue
    private let queue = DispatchQueue(label: "app.overbright.Overbright.hang-watchdog", qos: .utility)
    private let state = LockedState(State())
    /// Timer slack; small against the 3–5 s window.
    private static let leeway: DispatchTimeInterval = .milliseconds(50)

    /// A watchdog writing through `writer` from `ledger` (the engine's own pair), pinging the main queue.
    public convenience init(writer: TableWriter, ledger: SafetyLedger, journal: any DiagnosticsJournal) {
        self.init(writer: writer, ledger: ledger, journal: journal, pingInterval: EngineTiming.hangPing,
                  timeout: EngineTiming.hangTimeout, pinged: .main)
    }

    /// The designated initializer: tests shorten the intervals or ping a queue they can stall.
    init(writer: TableWriter, ledger: SafetyLedger, journal: any DiagnosticsJournal, pingInterval: Duration,
         timeout: Duration, pinged: DispatchQueue) {
        self.writer = writer; self.ledger = ledger; self.journal = journal
        self.pingInterval = pingInterval; self.timeout = timeout; self.pinged = pinged
    }

    deinit {
        state.withLock { $0.timer?.cancel() }
    }

    // MARK: Engine interface

    /// Runs while any display is scaled or dimmed (the engine switches it); off, it holds no timer and does no work.
    /// Safe from any thread.
    public func setActive(_ active: Bool) {
        state.withLock { s in
            if active {
                guard s.timer == nil else { return }
                s.generation &+= 1
                s.pingSentAt = nil
                s.firedForStall = false
                let generation = s.generation
                let timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
                timer.setEventHandler { @Sendable [weak self] in self?.tick(generation: generation) }
                timer.schedule(deadline: .now(), leeway: Self.leeway)
                s.timer = timer
                timer.activate()
            } else {
                guard let timer = s.timer else { return }
                s.generation &+= 1
                s.timer = nil
                s.pingSentAt = nil
                s.firedForStall = false
                timer.cancel()
            }
        }
    }

    /// Whether the watchdog fired since the last call (the engine then journals `hang.restored` and re-gates).
    public func consumeFiredFlag() -> Bool {
        state.withLock { s in
            defer { s.firedFlag = false }
            return s.firedFlag
        }
    }

    // MARK: Test probes

    /// Whether a timer runs.
    var isActive: Bool { state.withLock { $0.timer != nil } }
    /// Restores since the watchdog was made.
    var fireCount: Int { state.withLock { $0.fires } }
    /// Pings the main queue (or the test's queue) answered.
    var pongCount: Int { state.withLock { $0.pongs } }
    /// Uptime (ns) of the last restore.
    var lastFiredAt: UInt64? { state.withLock { $0.lastFiredAt } }

    // MARK: Watchdog queue

    /// The timer's handler (on the watchdog's queue; any thread in tests): send a ping, wait for its timeout, or fire.
    func tick(generation: UInt64) {
        enum Step { case idle, ping(UInt64), fire }
        let now = DispatchTime.now().uptimeNanoseconds
        let timeoutNanos = Self.nanoseconds(timeout)
        let step: Step = state.withLock { s in
            guard s.generation == generation, let timer = s.timer else { return .idle }
            guard let sent = s.pingSentAt else {
                s.pingID &+= 1
                s.pingSentAt = now
                timer.schedule(deadline: .now() + Self.interval(pingInterval), leeway: Self.leeway)
                return .ping(s.pingID)
            }
            let waited = now >= sent ? now - sent : 0
            guard waited >= timeoutNanos else {
                timer.schedule(deadline: .now() + .nanoseconds(Int(clamping: timeoutNanos - waited)),
                               leeway: Self.leeway)
                return .idle
            }
            timer.schedule(deadline: .now() + Self.interval(pingInterval), leeway: Self.leeway)
            guard !s.firedForStall else { return .idle }
            s.firedForStall = true
            return .fire
        }
        switch step {
        case .idle: break
        case .ping(let id): pinged.async { @Sendable [weak self] in self?.pong(id) }
        case .fire: fire()
        }
    }

    /// The pinged queue answered ping `id` (on the main queue; nonisolated, so it never traps off main).
    func pong(_ id: UInt64) {
        let recovered: Bool = state.withLock { s in
            guard s.pingID == id, s.pingSentAt != nil else { return false }
            s.pingSentAt = nil
            s.pongs += 1
            defer { s.firedForStall = false }
            return s.firedForStall
        }
        if recovered { log.info("hang watchdog: the main thread answers again") }
    }

    private func fire() {
        let result = EmergencyRestore.run(writer: writer, ledger: ledger)
        let firedAt = DispatchTime.now().uptimeNanoseconds
        state.withLock { s in
            s.firedFlag = true
            s.fires += 1
            s.lastFiredAt = firedAt
        }
        journal.record(JournalEvent(seconds: writer.time.now.sinceOrigin.timeInterval,
                                    category: LogCategory.engine.rawValue, display: nil, code: "hang.fired",
                                    values: ["displays": Double(result.displays), "epoch": Double(result.epoch)]))
        let displays = result.displays, epoch = result.epoch
        log.error("hang watchdog fired: \(displays, privacy: .public) baseline(s), epoch \(epoch, privacy: .public)")
    }

    // MARK: Helpers

    private static func nanoseconds(_ duration: Duration) -> UInt64 {
        UInt64(max(duration.timeInterval, 0) * 1_000_000_000)
    }

    private static func interval(_ duration: Duration) -> DispatchTimeInterval {
        .nanoseconds(Int(clamping: nanoseconds(duration)))
    }
}
