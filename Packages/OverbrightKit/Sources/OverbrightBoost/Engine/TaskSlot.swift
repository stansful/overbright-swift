// OverbrightBoost/Engine/TaskSlot.swift — one stored task of the engine (a gate poll, a ramp, the drift check, a
// deadline). ARCHITECTURE.md §8.1 rule 5 (no repeating timers: every periodic activity is a stored `Task` with
// `TimeSource.sleep`, cancelled on stop), §4.5 invariant 4 (zero tasks while off: a finished slot is empty).
// MainActor.

/// Holds at most one task. `run(_:)` cancels the previous one; a finished task empties the slot, so `isRunning` and
/// the engine's task count say exactly what is alive.
@MainActor final class TaskSlot {
    private var task: Task<Void, Never>?
    private var serial: UInt64 = 0

    /// An empty slot.
    init() {}

    /// Whether a task is alive in this slot.
    var isRunning: Bool { task != nil }

    /// Cancels the current task and starts `body` on the main actor.
    func run(_ body: @escaping @MainActor () async -> Void) {
        task?.cancel()
        serial &+= 1
        let mine = serial
        task = Task { @MainActor [weak self] in
            await body()
            guard let self, self.serial == mine else { return }
            self.task = nil
        }
    }

    /// Cancels the current task (its next `TimeSource.sleep` throws) and empties the slot.
    func cancel() {
        task?.cancel()
        task = nil
        serial &+= 1
    }

    /// Waits until the current task (if any) has finished.
    func wait() async {
        await task?.value
    }
}
