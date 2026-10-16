// OverbrightCore/Platform/Concurrency.swift — small, verified building blocks so modules never hand-roll threading.
// Ported from Cranny's CrannyCore/Platform/Concurrency.swift (the owner's MIT code). Two changes: `ObservationToken`
// takes its cancel action as a closure (ARCHITECTURE.md §3.6), so services such as `OwnEDRSurfaces` and
// `SystemSignals` hand out the same token type; and `ProcessRunner` is dropped (Overbright spawns no tools).
// ARCHITECTURE.md §3.1, §8.1 rule 6.
import Foundation
import Observation

// MARK: - Observation tokens

/// Keeps an observation alive; `cancel()` or deinit ends it (Cranny's Concurrency.swift).
@MainActor public final class ObservationToken {
    private var onCancel: (() -> Void)?
    /// A token that runs `onCancel` once, on `cancel()` or when released.
    public init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    /// Ends the observation; later calls do nothing.
    public func cancel() { onCancel?(); onCancel = nil }
    isolated deinit { onCancel?() }
}

// MARK: - Observation outside SwiftUI (macOS 14-safe; `Observations` is macOS 26+)

/// Calls `onChange` with the new value whenever something `value()` reads changes (Observation outside SwiftUI).
/// `value()` runs once at registration and once per change: each run both reads the value and registers what it
/// reads, so keep it cheap but never split it. `onChange` runs on the main actor, after the change, only when the
/// value differs from the last one delivered. Keep the returned token alive.
@MainActor @discardableResult
public func observe<T: Equatable>(_ value: @escaping @MainActor () -> T,
                                  onChange: @escaping @MainActor (T) -> Void) -> ObservationToken {
    let observer = Observer(value: value, onChange: onChange)
    observer.start()
    return ObservationToken { observer.stop() }       // the token keeps the observer alive until cancelled
}

@MainActor private final class Observer<T: Equatable> {
    let value: @MainActor () -> T
    let onChange: @MainActor (T) -> Void
    /// The value delivered last (set by `start()` before anything can fire).
    private var last: T?
    private var isStopped = false
    init(value: @escaping @MainActor () -> T, onChange: @escaping @MainActor (T) -> Void) {
        self.value = value; self.onChange = onChange
    }
    func start() { last = arm() }
    func stop() { isStopped = true }
    /// Evaluates `value` ONCE: the same pass returns the value and registers what it read for the next change.
    private func arm() -> T {
        withObservationTracking { value() } onChange: { [weak self] in
            Task { @MainActor in self?.fire() }
        }
    }
    private func fire() {
        guard !isStopped else { return }
        let now = arm()
        if now != last { last = now; onChange(now) }
    }
}

// MARK: - Durations

public extension Duration {
    /// Seconds as a `TimeInterval`, for `Date` and `DispatchTime` arithmetic and for logging.
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}

// MARK: - Debounce

/// Trailing debounce on the main actor (settings-driven rebuilds, background saves).
///
/// Energy: the action's task runs at `priority`; nil inherits the caller's (on the main actor: user-initiated). Pass
/// `.utility` for work nobody waits on, such as background saves and notification-driven reloads: the `@concurrent`
/// work the action awaits then runs at utility QoS (efficiency cores, throttled I/O).
@MainActor public final class Debouncer {
    private let delay: Duration
    private let priority: TaskPriority?
    private var task: Task<Void, Never>?
    /// A debouncer that waits `delay` after the last `schedule(_:)`; its actions run at `priority` (nil: inherited).
    public init(delay: Duration, priority: TaskPriority? = nil) {
        self.delay = delay
        self.priority = priority
    }
    /// Runs `action` after the delay unless another `schedule` or `cancel` comes first.
    public func schedule(_ action: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task(priority: priority) { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    /// Drops the pending action.
    public func cancel() { task?.cancel(); task = nil }
}
