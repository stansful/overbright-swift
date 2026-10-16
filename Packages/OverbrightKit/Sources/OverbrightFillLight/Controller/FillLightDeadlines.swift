// OverbrightFillLight/Controller/FillLightDeadlines.swift — the Fill Light controller's one-shot deadlines.
// ARCHITECTURE.md §8.1 rule 5 (stored tasks on the injected `TimeSource`, no repeating timer), §10.9 (zero work while
// off), D6 (macOS's up-ramp); DESIGN.md §17.
//
// Thread: main actor. Each kind of deadline is at most one stored task sleeping on the injected `TimeSource`;
// scheduling again replaces it, and `cancelAll()` leaves nothing running.
import OverbrightCore

/// The camera rule's next deadline and the headroom settle reads of `FillLightController`.
final class FillLightDeadlines {
    private let time: any TimeSource
    private var ruleTask: Task<Void, Never>?
    private var ruleDeadline: MonotonicInstant?
    private var settleTask: Task<Void, Never>?

    /// Deadlines on `time`; none scheduled.
    init(time: any TimeSource) { self.time = time }

    /// Calls `fire` once at `deadline` (nil: nothing pending, the task is cancelled). The deadline already scheduled
    /// keeps its task.
    func scheduleRule(at deadline: MonotonicInstant?, _ fire: @escaping () -> Void) {
        guard deadline != ruleDeadline else { return }
        ruleTask?.cancel()
        ruleTask = nil
        ruleDeadline = deadline
        guard let deadline else { return }
        ruleTask = Task { [weak self, time] in
            do { try await time.sleep(for: deadline - time.now) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.ruleTask = nil
            self.ruleDeadline = nil
            fire()
        }
    }

    /// Calls `read` at each of `FillLightTiming.headroomSettleReads` from now (while macOS raises the grant),
    /// replacing settle reads already scheduled.
    func scheduleSettle(_ read: @escaping () -> Void) {
        settleTask?.cancel()
        let offsets = FillLightTiming.headroomSettleReads
        settleTask = Task { [weak self, time] in
            var elapsed: Duration = .zero
            for offset in offsets {
                do { try await time.sleep(for: offset - elapsed) } catch { return }
                elapsed = offset
                guard !Task.isCancelled, self != nil else { return }
                read()   // may schedule new settle reads, which cancel this task
            }
        }
    }

    /// Stops the settle reads.
    func cancelSettle() {
        settleTask?.cancel()
        settleTask = nil
    }

    /// Stops everything.
    func cancelAll() {
        scheduleRule(at: nil) {}
        cancelSettle()
    }
}
