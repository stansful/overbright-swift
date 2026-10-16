// OverbrightSignals/Monitor/DeadlineTimer.swift — one pending deadline on the main actor. ARCHITECTURE.md §8.1 rule 5
// (no repeating timers: every periodic activity is a stored task sleeping on the `TimeSource`, cancelled on stop), D22.
// Thread: main. Tests drive it with `ManualTimeSource`, so a pending deadline is one sleeper and none is zero sleepers.
import OverbrightCore

/// Runs one action after a delay unless rescheduled or cancelled first.
final class DeadlineTimer {
    private let time: any TimeSource
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    /// A timer on `time`.
    init(time: any TimeSource) { self.time = time }

    /// Whether an action is waiting.
    var isPending: Bool { task != nil }

    /// Replaces any pending action with `action` after `delay` (at once for a zero or negative delay, on the next
    /// main-actor turn). The deadline is fixed now, so a task that starts late still wakes on time.
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        schedule(at: time.now + delay, action)
    }

    /// Replaces any pending action with `action` at `deadline`.
    func schedule(at deadline: MonotonicInstant, _ action: @escaping @MainActor () -> Void) {
        task?.cancel()
        generation &+= 1
        let current = generation
        task = Task { [weak self, time] in
            do { try await time.sleep(for: deadline - time.now) } catch { return }
            guard let self, self.generation == current else { return }
            self.task = nil
            action()
        }
    }

    /// Drops the pending action.
    func cancel() {
        task?.cancel()
        task = nil
        generation &+= 1
    }

    isolated deinit { task?.cancel() }
}
