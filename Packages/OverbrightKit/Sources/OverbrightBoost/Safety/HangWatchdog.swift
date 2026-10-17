// OverbrightBoost/Safety/HangWatchdog.swift — restores the displays when the main thread stalls while scaled.
// ARCHITECTURE.md §4.6, §7.4, §8.1 rules 2 and 4; D7, D29. Thread: its own utility queue (a `DispatchSourceTimer`, the
// one sanctioned repeating timer), never the main actor; it touches displays only through
// `TableWriter.writeBaselines(fromLedger:)` under the ledger lock (`EmergencyRestore`), and never calls
// `DispatchQueue.main.sync`. Owned by WP5 (seeded by WP0a with the §10.0 signatures).
//
// While active (the safety ledger's occupancy observer switches it on while the ledger holds any display, from the
// write that marks the first one to the write that empties it: `SafetyLedger.observeOccupancy`, which calls `setActive`
// inside the ledger lock), the timer sends a ping to the main queue every `hangPing` (2 s). A ping still unanswered
// `hangTimeout` (3 s) after it was sent means the main thread is stuck: under the ledger lock the watchdog bumps the
// hang epoch, writes every ledger baseline and forgets the entries, then raises the fired flag and journals
// `hang.fired`. It fires once per stall; the next pong re-arms it. A stall is therefore caught 3–5 s after it starts
// (3 s when it starts while a ping waits for its answer, almost 5 s when it starts just after an answer). The timer
// wakes only at ping times (the grid points below) and at one timeout deadline, never in between.
//
// Pings go out on the shared 2 s grid of the engine's time source (ARCHITECTURE.md D29; `TimeSource.nextGridPoint`):
// the first one when the ledger fills, every later one at the next multiple of `hangPing` since the time source's
// origin, at most `hangPing` away, so the ping and its main-queue pong share the wake-up of the drift check and of
// Signals' watch, which wait for the same points. While a ping waits for its answer the timer wakes at the earlier of
// its timeout deadline and the next grid point, so a new ping always follows an answer within `hangPing` (an answer
// that comes after a short first wait would otherwise let the next ping slip to the deadline, and a stall right after
// it would take up to 6 s to catch). The deadline itself (ping + `hangTimeout`), the 50 ms leeway and the
// once-per-stall rule are unchanged.
import Dispatch
import Foundation
import OverbrightCore
import os

nonisolated private let log = Log.logger(.engine)

/// Ping-pong with the main thread every 2 s while the safety ledger holds any display; a ping unanswered for 3 s bumps
/// the hang epoch and writes every ledger baseline, then records that it fired.
public nonisolated final class HangWatchdog: Sendable {
    /// Everything that changes, behind one lock. Lock order: the ledger's, then this one (`setActive` runs inside the
    /// ledger lock); this lock is never held while the ledger lock is taken.
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
        var pings = 0
        var pongs = 0
        /// Uptime (ns) of the last restore.
        var lastFiredAt: UInt64?
        /// Uptime (ns) the ping whose timeout fired the last restore was sent at.
        var firedPingSentAt: UInt64?
        /// The delay (ns) the timer was last scheduled with.
        var lastDelay: UInt64?
    }

    /// What one tick does.
    enum Step: Hashable, Sendable {
        /// Nothing: the ping that is out has not timed out yet, or the watchdog already fired for this stall.
        case idle
        /// Send ping `id` to the pinged queue.
        case ping(UInt64)
        /// The ping timed out: restore.
        case fire
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

    /// Runs while the safety ledger holds any display: the engine hands this to `SafetyLedger.observeOccupancy`, whose
    /// observer calls it inside the ledger lock (lock order: the ledger's, then the watchdog's state), so it must never
    /// use the ledger. Off, it holds no timer and does no work. Safe from any thread.
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
    /// Uptime (ns) the ping whose timeout fired the last restore was sent at.
    var lastTimedOutPingSentAt: UInt64? { state.withLock { $0.firedPingSentAt } }
    /// Pings sent since the watchdog was made.
    var pingCount: Int { state.withLock { $0.pings } }
    /// The delay (ns) of the timer's last schedule after a tick.
    var lastScheduledDelay: UInt64? { state.withLock { $0.lastDelay } }

    /// Returns once every timer handler queued before the call has run: after `setActive(false)` no tick, and no
    /// restore, is left in flight (a cancelled timer calls its handler no more).
    func drainQueue() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }

    // MARK: Watchdog queue

    /// The timer's handler (on the watchdog's queue; any thread in tests): send a ping, wait for its timeout, or fire.
    func tick(generation: UInt64) {
        let now = DispatchTime.now().uptimeNanoseconds
        let interval = Self.nanoseconds(pingInterval), timeout = Self.nanoseconds(timeout)
        // Read before the deadline's `.now()`, so the timer never fires ahead of the grid point (uptime and the time
        // source's continuous clock advance together while the Mac is awake).
        let toGrid = Self.nextPingDelay(sinceOrigin: writer.time.now.sinceOrigin, interval: pingInterval)
        let step: Step = state.withLock { s in
            guard s.generation == generation, let timer = s.timer else { return .idle }
            let (step, next) = Self.gridStep(&s, at: now, toGrid: toGrid, interval: interval, timeout: timeout)
            timer.schedule(deadline: .now() + .nanoseconds(Int(clamping: next)), leeway: Self.leeway)
            s.lastDelay = next
            return step
        }
        switch step {
        case .idle: break
        case .ping(let id): pinged.async { @Sendable [weak self] in self?.pong(id) }
        case .fire: fire()
        }
    }

    /// The pinged queue answered ping `id` (on the main queue; nonisolated, so it never traps off main).
    func pong(_ id: UInt64) {
        let recovered = state.withLock { Self.answer(&$0, ping: id) }
        if recovered { log.info("hang watchdog: the main thread answers again") }
    }

    /// One tick at uptime `now` (ns) on the state alone: send a ping when none is out; once the ping that is out has
    /// waited `timeout`, fire, once per stall; otherwise nothing. Returns the step and the delay (ns) to the next tick:
    /// `interval` after a ping or a timeout, else the rest of the ping's timeout, so the timer wakes only at ping times
    /// and at one deadline (`gridStep` moves the ping times onto the grid). Pure, so `HangWatchdogTests` checks the
    /// 3–5 s window on explicit times.
    static func step(_ s: inout State, at now: UInt64, interval: UInt64,
                     timeout: UInt64) -> (step: Step, next: UInt64) {
        guard let sent = s.pingSentAt else {
            s.pingID &+= 1
            s.pingSentAt = now
            s.pings += 1
            return (.ping(s.pingID), interval)
        }
        let waited = now >= sent ? now - sent : 0
        guard waited >= timeout else { return (.idle, timeout - waited) }
        guard !s.firedForStall else { return (.idle, interval) }
        s.firedForStall = true
        s.firedPingSentAt = sent
        return (.fire, interval)
    }

    /// One tick as the timer runs it: `step`, with the delay to the next tick moved onto the grid. While a ping is out
    /// and has not fired, the next tick comes at the earlier of `step`'s delay and `toGrid` (the delay to the next grid
    /// point, at most `interval`): a ping's next tick lands on the grid, and a ping answered after a grid point is
    /// followed by the next one within `interval` of its answer. After a restore `step`'s delay stands. Pure, so
    /// `HangWatchdogTests` checks the 3–5 s window on explicit times and grid phases.
    static func gridStep(_ s: inout State, at now: UInt64, toGrid: UInt64, interval: UInt64,
                         timeout: UInt64) -> (step: Step, next: UInt64) {
        let (step, next) = Self.step(&s, at: now, interval: interval, timeout: timeout)
        guard s.pingSentAt != nil, !s.firedForStall else { return (step, next) }
        return (step, min(next, toGrid))
    }

    /// The delay (ns, rounded up) from `sinceOrigin` on the writer's time source to the next point of its `interval`
    /// grid: in (0, interval] (`MonotonicInstant.nextGridPoint`). Pure.
    static func nextPingDelay(sinceOrigin: Duration, interval: Duration) -> UInt64 {
        let now = MonotonicInstant(sinceOrigin: sinceOrigin)
        return nanosecondsRoundedUp(MonotonicInstant.nextGridPoint(after: now, every: interval) - now)
    }

    /// Ping `id` was answered, on the state alone: true when the answer ends a stall the watchdog fired for (the next
    /// stall may fire again). An answer to an older ping, or after a switch, changes nothing.
    static func answer(_ s: inout State, ping id: UInt64) -> Bool {
        guard s.pingID == id, s.pingSentAt != nil else { return false }
        s.pingSentAt = nil
        s.pongs += 1
        defer { s.firedForStall = false }
        return s.firedForStall
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

    static func nanoseconds(_ duration: Duration) -> UInt64 {
        UInt64(max(duration.timeInterval, 0) * 1_000_000_000)
    }

    /// Whole nanoseconds, a fraction rounded up (a positive delay never becomes zero); 0 for a delay that is not
    /// positive, `UInt64.max` beyond its range.
    static func nanosecondsRoundedUp(_ duration: Duration) -> UInt64 {
        guard duration > .zero else { return 0 }
        let (seconds, attoseconds) = duration.components
        let (whole, fraction) = attoseconds.quotientAndRemainder(dividingBy: 1_000_000_000)
        let (scaled, overflow) = UInt64(seconds).multipliedReportingOverflow(by: 1_000_000_000)
        guard !overflow else { return .max }
        return scaled + UInt64(whole) + (fraction > 0 ? 1 : 0)
    }
}
