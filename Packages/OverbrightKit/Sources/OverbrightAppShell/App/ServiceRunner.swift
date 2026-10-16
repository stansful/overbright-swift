// OverbrightAppShell/App/ServiceRunner.swift — runs the launch work and the stops over the `ServiceStack`.
// ARCHITECTURE.md §7.4 (launch check first, then the services, Displays first and Boost last; the ramped stop in
// reverse, Boost first, within `EngineTiming.quitTimeout`; `stopNow()` as the synchronous fallback), D7, D27.
// MainActor. The quit (`QuitFlow`) and the signal handlers (`SignalHandlers`' main-actor stop) both stop through it.
// A stop that arrives while a service's `start()` is suspended reaches that service before it has started (the engine,
// for one, ignores a stop until its start finished); so a start that finishes after a stop is followed by that
// service's `stopNow()`, and nothing runs after the stop.
import OverbrightBoost
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Starts and stops the services of one launch, in their one order.
final class ServiceRunner {
    /// Where the services are.
    enum Phase: Equatable { case idle, starting, started, stopping, stopped }

    private let stack: ServiceStack
    private let time: any TimeSource
    private let journal: any DiagnosticsJournal
    /// Where the services are.
    private(set) var phase = Phase.idle

    /// A runner over `stack`; `time` bounds the ramped stop.
    init(stack: ServiceStack, time: any TimeSource, journal: any DiagnosticsJournal) {
        self.stack = stack; self.time = time; self.journal = journal
    }

    /// The launch work after the launch check (§7.4): every service in start order; `beforeBoost` runs right before
    /// the engine starts (the launch check's outcome reaches it while the directory already lists the displays). A
    /// stop that arrives meanwhile ends it: the service whose start was under way is stopped once its start returns.
    func start(beforeBoost: () -> Void = {}) async {
        guard phase == .idle else { return }
        phase = .starting
        for role in ServiceStack.Role.allCases {
            guard let service = stack.service(role) else { continue }
            if role == .boost { beforeBoost() }
            if phase != .starting { return }                        // a stop (signal) arrived meanwhile
            await service.start()
            guard phase == .starting else {                         // the stop came while it started: it missed it
                log.info("\(service.serviceName, privacy: .public) started after the stop; stopping it now")
                service.stopNow()
                return
            }
            log.info("started \(service.serviceName, privacy: .public)")
        }
        if phase == .starting { phase = .started }
        record("services.started")
    }

    /// The ramped stop: every service in stop order (Boost first), giving up waiting after `limit`. Returns true when
    /// every stop finished in time. A second call while one runs waits for nothing and returns false.
    @discardableResult
    func stop(within limit: Duration) async -> Bool {
        guard phase == .started || phase == .starting else { return phase == .stopped }
        phase = .stopping
        let services = stack.stopOrder
        let stopping = Task { @MainActor in for service in services { await service.stop() } }
        let finished = await Self.firstOf(stopping, orAfter: limit, time: time)
        phase = .stopped
        record(finished ? "services.stopped" : "services.stopTimedOut")
        if !finished { log.error("the ramped stop did not finish within \(limit.timeInterval, privacy: .public) s") }
        return finished
    }

    /// The synchronous fallback (`applicationWillTerminate`): `stopNow()` in stop order, no ramp, baselines written.
    /// Nothing when no service ever started.
    func stopNow() {
        guard phase != .idle else { return }
        for service in stack.stopOrder { service.stopNow() }
        phase = .stopped
    }

    /// Waits for `task` or `limit` on `time`, whichever comes first; true when the task finished. A hung stop never
    /// holds the quit: the wait ends at `limit` while the task runs on (a task group would wait for it).
    private static func firstOf(_ task: Task<Void, Never>, orAfter limit: Duration, time: any TimeSource) async -> Bool {
        await Race().run(task, limit: limit, time: time)
    }

    private func record(_ code: String) {
        journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: LogCategory.app.rawValue,
                                    display: nil, code: code, values: [:]))
    }
}

/// Resumes once: true when the work finished, false when the limit passed first.
private final class Race {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timer: Task<Void, Never>?

    func run(_ work: Task<Void, Never>, limit: Duration, time: any TimeSource) async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            timer = Task { [weak self] in
                do { try await time.sleep(for: limit) } catch { return }
                self?.finish(false)
            }
            Task { [weak self] in
                await work.value
                self?.finish(true)
            }
        }
    }

    private func finish(_ value: Bool) {
        timer?.cancel()
        timer = nil
        continuation?.resume(returning: value)
        continuation = nil
    }
}
