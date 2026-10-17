// OverbrightBoost/Safety/SignalHandlers.swift — TERM, INT and HUP restore the displays before the process exits.
// ARCHITECTURE.md §7.4, §8.1 rules 2 and 6; D7. Thread: a dedicated serial queue (`DispatchSource.makeSignalSource`),
// never the main actor; the only wait is a semaphore on that queue (never on main). Owned by WP5 (seeded by WP0a with
// the §10.0 signatures).
//
// `install()` sets the three signals to SIG_IGN (so their default action no longer kills the process) and listens with
// dispatch sources. On a signal: under the ledger lock, bump the hang epoch and write every ledger baseline
// (`EmergencyRestore`: the displays are neutral at once, and the ramped stop that follows can no longer re-scale them),
// then ask the main actor for the normal stop and wait at most `signalStopTimeout` (1 s), then exit(0). A hung main
// thread therefore no longer makes `kill` ineffective.
import Dispatch
import Foundation
import OverbrightCore
import os

nonisolated private let log = Log.logger(.engine)

/// On a signal: ledger baselines through `writer` at once, then the main-actor `stop` with a 1 s timeout, then exit.
public nonisolated final class SignalHandlers: Sendable {
    /// The signals handled.
    static let handledSignals: [Int32] = [SIGTERM, SIGINT, SIGHUP]

    private struct State {
        var sources: [any DispatchSourceSignal] = []
        var previousActions: [(signal: Int32, action: sig_t?)] = []
        var handling = false
    }

    /// How the signal queue waits for the main-actor stop: true when `done` was signalled within `timeout`.
    typealias StopWait = @Sendable (_ done: DispatchSemaphore, _ timeout: Duration) -> Bool

    private let writer: TableWriter
    private let stop: @MainActor @Sendable () async -> Void
    private let timeout: Duration
    private let wait: StopWait
    private let terminate: @Sendable (Int32) -> Void
    private let queue = DispatchQueue(label: "app.overbright.Overbright.signals", qos: .userInitiated)
    private let state = LockedState(State())

    /// Handlers that write through `writer` and then ask for `stop` (the engine's ramped stop).
    public convenience init(writer: TableWriter, stop: @escaping @MainActor @Sendable () async -> Void) {
        self.init(writer: writer, stop: stop, timeout: EngineTiming.signalStopTimeout, terminate: { code in exit(code) })
    }

    /// The designated initializer: tests replace `exit`, and the wait, so that what they check never depends on how
    /// soon a loaded main actor runs the stop (§9.1).
    init(writer: TableWriter, stop: @escaping @MainActor @Sendable () async -> Void, timeout: Duration,
         wait: @escaping StopWait = SignalHandlers.waitAtMost, terminate: @escaping @Sendable (Int32) -> Void) {
        self.writer = writer; self.stop = stop; self.timeout = timeout; self.wait = wait; self.terminate = terminate
    }

    /// The shipped wait: blocks the signal queue (never the main thread) until `done` is signalled or `timeout` passed.
    static let waitAtMost: StopWait = { done, timeout in
        let nanoseconds = Int(clamping: Int64(max(timeout.timeInterval, 0) * 1_000_000_000))
        return done.wait(timeout: .now() + .nanoseconds(nanoseconds)) == .success
    }

    deinit {
        state.withLock { s in for source in s.sources { source.cancel() } }
    }

    /// Ignores the default actions of TERM, INT and HUP and installs the dispatch sources (once; later calls do
    /// nothing). Call it from the engine's start, never in a test process through this initializer.
    public func install() {
        state.withLock { s in
            guard s.sources.isEmpty else { return }
            for number in Self.handledSignals {
                s.previousActions.append((number, signal(number, SIG_IGN)))
                let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
                source.setEventHandler { @Sendable [weak self] in self?.handle(number) }
                source.activate()
                s.sources.append(source)
            }
        }
    }

    // MARK: Tests

    /// Cancels the sources and puts the previous signal actions back.
    func uninstall() {
        state.withLock { s in
            for source in s.sources { source.cancel() }
            for previous in s.previousActions { signal(previous.signal, previous.action) }
            s.sources = []
            s.previousActions = []
        }
    }

    /// Number of installed dispatch sources.
    var sourceCount: Int { state.withLock { $0.sources.count } }

    // MARK: Signal queue

    /// The handler (on the signal queue; any thread but the main one, which runs `stop`). Handles the first signal
    /// only: the process exits at its end.
    func handle(_ number: Int32) {
        let first: Bool = state.withLock { s in
            defer { s.handling = true }
            return !s.handling
        }
        guard first else { return }
        let restored = EmergencyRestore.run(writer: writer, ledger: writer.ledger)
        record("signal.received", values: ["signal": Double(number), "displays": Double(restored.displays)])
        log.info("signal \(number, privacy: .public): \(restored.displays, privacy: .public) baseline(s) written")

        let done = DispatchSemaphore(value: 0)
        let stop = stop
        Task { @MainActor in
            await stop()
            done.signal()
        }
        if !wait(done, timeout) {
            record("signal.stopTimedOut")
            log.error("signal \(number, privacy: .public): the main-actor stop did not finish in time")
        }
        terminate(0)
    }

    private func record(_ code: String, values: [String: Double] = [:]) {
        writer.journal.record(JournalEvent(seconds: writer.time.now.sinceOrigin.timeInterval,
                                           category: LogCategory.engine.rawValue, display: nil, code: code,
                                           values: values))
    }
}
