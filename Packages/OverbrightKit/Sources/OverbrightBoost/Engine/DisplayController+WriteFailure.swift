// OverbrightBoost/Engine/DisplayController+WriteFailure.swift — what a controller does when WindowServer refuses a
// write: land on the baseline, keep the windows until it has, retry within the repair budget.
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
        /// Remove the trigger once the table is at or below the baseline.
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

    /// The landing of a display with nothing applied (a disarm or Back to Standard while arming, gating or at rest):
    /// the baseline when the table may be off it, then the windows. While WindowServer refuses that baseline and the
    /// ledger still marks the display, the windows stay (`keepsWindowsWhileMarked`, §4.5 invariants 2 and 9) and the
    /// at-rest retry of the next reduction removes them once the baseline is written. False when the baseline write
    /// failed (the caller makes sure a reduction follows).
    @discardableResult
    func landUnscaled() -> Bool {
        if writeBaselineNow() {
            removeWindows()
            return true
        }
        if keepsWindowsWhileMarked {
            deps.journal.record("order.windowsKept", display: key, time: deps.time, category: .gamma)
        } else {
            removeWindows()
        }
        return false
    }

    /// `keepsWindowsAfterFailedLanding` for a display the ledger marks while our latest write is not above the
    /// baseline: a scaled write that threw keeps its mark but never became `lastWrite`, and WindowServer may
    /// nevertheless have taken it, so a table above the baseline may be on screen that still needs the trigger's EDR
    /// request. The windows go only once the table reads back as the baseline (WindowServer did not take that write,
    /// or replaced it); a table that cannot be read keeps them.
    var keepsWindowsWhileMarked: Bool {
        guard trigger != nil, deps.ledger.isMarked(key) else { return false }
        guard let baseline = baseline ?? deps.ledger.entry(for: key)?.baseline,
              let read = try? deps.gamma.read(ref.id) else { return true }
        return !read.matches(baseline, tolerance: Self.sameTableTolerance)
    }

    /// A display at rest (idle or failed) whose last landing failed is still scaled or dimmed, or whose table may be
    /// off its baseline (a scaled write that threw left its ledger entry, `tableMayBeOffBaseline`): every reduction
    /// writes its baseline again (the master off must end at the baseline, §4.5 invariant 4), then orders out the
    /// windows kept meanwhile (invariant 2). A base event that could not be written yet is judged again first (§4.8).
    func retryLandingAtRest() {
        guard !isActive else { return }
        settlePendingRebase()
        let scaled = isScaledOrDimmed || tableMayBeOffBaseline
        guard scaled || trigger != nil else { return }
        if scaled {
            deps.journal.record("baseline.retried", display: key, time: deps.time, category: .gamma)
            guard writeBaselineNow() else { return }
        }
        removeWindows()
    }
}
