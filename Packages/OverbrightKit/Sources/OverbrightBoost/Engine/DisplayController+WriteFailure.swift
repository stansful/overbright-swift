// OverbrightBoost/Engine/DisplayController+WriteFailure.swift — what a controller does when WindowServer (or the
// overlay) refuses a write: land on the baseline, keep the windows until it has, retry within the repair budget.
// ARCHITECTURE.md §4.5 invariants 2 (un-scale before removing a window), 4 (off means the baseline and no work) and 8
// (flicker safety), §9.1 ("every sequence ending in off leaves every table equal to its baseline"), D9. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// One ramp's parameters, kept so a ramp can be retried after a failed write.
    struct RampSpec: Hashable, Sendable {
        /// The light gain at the end.
        var gain: Double
        /// Duration class (standard, Reduce Motion, Back to Standard).
        var kind: RampPlanner.Kind
        /// Who asked (the rate limiter and the oscillation detector).
        var origin: Origin
        /// The phase once the table is at `gain` (nil keeps the phase: a dim factor returning to 1 while arming).
        var finalPhase: EnginePhase?
        /// Remove the trigger and overlay once the table is at or below the baseline.
        var removesWindowsAtEnd: Bool
        /// False for Back to Standard and the ramped stop, which never wait.
        var rateLimited: Bool
    }

    /// A ramp step was not written. The table is where the last successful write left it, so the ramp neither claims
    /// its target nor removes a window: it lands on the baseline at once (a transition of its own for the rate limiter
    /// and the oscillation detector). A ramp whose target is the baseline is then done (true: finish it). Any other
    /// ramp, and a landing that failed too, is retried after `resetReapplyDelay` and counted as a repair, so a write
    /// that keeps failing trips `repairBudgetExceeded` instead of looping. Off the console the session row applies.
    /// - Parameter before: the applied gain before the failed step.
    func rampStepFailed(_ ramp: RampSpec, before: Double, serial: UInt64, stamp: UInt64) async -> Bool {
        deps.journal.record("ramp.writeFailed", display: key, values: ["target": ramp.gain, "applied": appliedGain],
                            time: deps.time, category: .gamma)
        if isOffConsole || !parameters.isSessionActive {
            shield(.notOnConsole)                                         // write B, windows removed, no more writes
            return false
        }
        let landed = writeBaselineNow()
        if landed, abs(before - 1) > TableWriter.neutralTolerance,
           flicker.record(before > 1 ? .down : .up, at: deps.time.now, origin: .automatic) {
            fail(.oscillation)
            return false
        }
        if landed, abs(ramp.gain - 1) <= TableWriter.neutralTolerance { return true }
        if countRepair() {
            fail(.repairBudgetExceeded)
            return false
        }
        guard await sleep(EngineTiming.resetReapplyDelay, stamp), rampSerial == serial else { return false }
        deps.journal.record("ramp.retried", display: key, values: ["target": ramp.gain], time: deps.time)
        startRamp(ramp, setsRampingPhase: false)
        return false
    }

    /// Writes the baseline at once and goes idle (windows removed after it). When WindowServer refuses the write, the
    /// windows stay and a disarm ramp takes over, retried by `rampStepFailed` within the repair budget.
    func landAndGoIdle(kind: RampPlanner.Kind, rateLimited: Bool = true) {
        guard writeBaselineNow() else {
            phase = .disarming
            startRamp(to: 1, kind: kind, origin: .automatic, finalPhase: .idle, removesWindowsAtEnd: true,
                      setsRampingPhase: false, rateLimited: rateLimited)
            return
        }
        removeWindows()
        phase = .idle
        settled()
    }

    /// A display at rest (idle or failed) whose last landing failed is still scaled or dimmed: every reduction writes
    /// its baseline again (the master off must end at the baseline, §4.5 invariant 4). A base event that could not be
    /// written yet is judged again first (§4.8).
    func retryLandingAtRest() {
        guard !isActive else { return }
        settlePendingRebase()
        guard isScaledOrDimmed || (mechanism == .table && lastWriteIsScaled) else { return }
        deps.journal.record("baseline.retried", display: key, time: deps.time, category: .gamma)
        writeBaselineNow()
    }
}
