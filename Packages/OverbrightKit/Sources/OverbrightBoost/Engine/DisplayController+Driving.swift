// OverbrightBoost/Engine/DisplayController+Driving.swift — the seam the self-test and the calibration drive.
// ARCHITECTURE.md §4.1, §5.2, §7.5, §8.4, §10.0 (`DisplayControllerDriving`, owned by the contract owner). The engine has
// returned every display to Standard before it hands a controller out; nothing here writes a table except through
// `TableWriter`. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController: DisplayControllerDriving {
    /// The display driven.
    var display: DisplayRef { ref }

    /// Shows one rung with the table at its baseline (the self-test measures triggers only). The baseline is captured
    /// afresh, so a calibration never multiplies a curve from before a profile or preset change. The trigger reports
    /// occlusion and screen moves like an armed one (§4.7): moved to another screen it is removed at once, and either
    /// ends the driven session on this display (`onDrivenWindowLost`). A calibration of a Compatibility-mode display
    /// shows the overlay instead (`armOverlayForCalibration`).
    func arm(rung request: TriggerRequest) async -> Bool {
        generation += 1
        let stamp = generation
        cancelAllTasks()
        if calibratesOverlay { return armOverlayForCalibration(request) }
        refreshBaseline()
        let handle: any TriggerHandle
        do {
            handle = try deps.triggers.makeTrigger(request, on: ref)
        } catch {
            return false
        }
        handle.onOcclusionChange = { [weak self, weak handle] occluded in
            guard let self, let handle else { return }
            self.windowOcclusionChanged(occluded, isCurrentWindow: handle === self.trigger)
        }
        handle.onScreenChange = { [weak self, weak handle] displayID in
            guard let self, let handle else { return }
            self.windowMoved(to: displayID, isCurrentWindow: handle === self.trigger)
        }
        let presented = await handle.present(request.pixel)
        guard presented, isCurrent(stamp) else {
            handle.remove()
            return false
        }
        let previous = trigger
        trigger = handle
        previous?.remove()
        currentRung = LadderPlanner.table.first { $0.strategy == request.strategy && $0.pixel == request.pixel }
        phase = .arming(rung: currentRung?.number ?? 0)
        return true
    }

    /// A calibration in Compatibility mode measures the overlay, never the table or a trigger (§5.2: its own record;
    /// D5): the overlay at factor 1 asking for the rung's headroom tag (the display's potential), its own EDR request
    /// (§7.5). No table is written and no trigger is made, so a display moved to Compatibility mode to stay clear of
    /// table writes (next to an S1 booster) stays clear of them.
    func armOverlayForCalibration(_ request: TriggerRequest) -> Bool {
        removeTrigger()
        guard ensureOverlay(), let overlay else { return false }
        drivenOverlayRequest = max(request.headroomTag, 1)
        do {
            try overlay.setFactor(1, headroomRequest: drivenOverlayRequest)
        } catch {
            deps.journal.record("overlay.failed", display: key, time: deps.time, category: .trigger)
            return false
        }
        resetApplied()
        currentRung = nil
        phase = .arming(rung: 0)
        return true
    }

    /// A fresh reading of this display.
    func readHeadroom() -> HeadroomReading? { takeReading() }

    /// Baseline, then the trigger removed (§4.5 invariant 2).
    func disarm() async {
        stopNow()
    }

    /// Back to Standard at once: baseline written, trigger removed.
    func returnToStandard() {
        stopNow()
    }

    /// A fresh baseline for a driven session (§4.8): the stored one may predate a profile, preset or HDR change made
    /// while the display was idle (a base event still pending is judged first). Kept while our own scaled write, or
    /// the old curve a re-base could not replace yet, is still on the table (never captured, §4.5 invariant 5). A
    /// rejected or failed read leaves no baseline, so a calibration write is refused.
    @discardableResult
    func refreshBaseline() -> Bool {
        guard mechanism == .table, facts.gammaCapacity > 0, !isScaledOrDimmed, !lastWriteIsScaled else {
            return baseline != nil
        }
        if !isActive { settlePendingRebase() }
        if let read = try? deps.gamma.read(ref.id), isOwnStaleWrite(read) { return true }
        baseline = nil
        return captureBaseline(failsOnReject: false)
    }

    /// Calibration only: `factor` × the baseline through `TableWriter.writeCalibrationFactor`, which refuses anything
    /// above `maxFactor` or the reading's calibration ceiling, a stale reading and a stale hang epoch (the session's
    /// stamp, taken when it started: after a hang restore nothing is scaled again until a new session starts). In
    /// Compatibility mode the overlay's factor, under the same checks, and no table write.
    func writeCalibrationFactor(_ factor: Double, maxFactor: Double) throws {
        guard !isOffConsole, parameters.isSessionActive else { throw GammaError.writeRefused }
        if calibratesOverlay { return try setOverlayCalibrationFactor(factor, maxFactor: maxFactor) }
        if baseline == nil, !captureBaseline(failsOnReject: false) { throw GammaError.writeRefused }
        guard let baseline, let reading = takeReading() else { throw GammaError.writeRefused }
        try deps.writer.writeCalibrationFactor(factor, of: baseline, to: ref, reading: reading, maxFactor: maxFactor,
                                               epoch: epochStamp)
        lastWrite = (baseline, factor)
        appliedFactor = factor
        appliedGain = FactorMath.lightGain(forTableFactor: factor, domain: .encoded)
        notify()
    }

    /// The overlay's calibration factor: `TableWriter.checkCalibrationFactor` with a fresh reading, then the factor with
    /// the request the arm made.
    func setOverlayCalibrationFactor(_ factor: Double, maxFactor: Double) throws {
        guard let overlay, let reading = takeReading() else { throw GammaError.writeRefused }
        try deps.writer.checkCalibrationFactor(factor, on: ref, reading: reading, maxFactor: maxFactor)
        do {
            try overlay.setFactor(factor, headroomRequest: drivenOverlayRequest)
        } catch {
            deps.journal.record("overlay.failed", display: key, time: deps.time, category: .trigger)
            throw GammaError.writeRefused
        }
        appliedFactor = factor
        appliedGain = FactorMath.lightGain(forTableFactor: factor, domain: .encoded)
        notify()
    }

    /// A driven display lost its trigger or overlay (occluded, or moved to another screen): Standard at once with the
    /// windows removed (forced: a window on another screen must never request EDR there), then the session hears it.
    func drivenWindowLost(_ reason: CalibrationAbortReason) {
        deps.journal.record("driven.windowLost", display: key, time: deps.time, category: .trigger)
        generation += 1
        cancelAllTasks()
        writeBaselineNow()
        removeWindows(force: true)
        if !phase.isFailed { phase = .idle }
        onDrivenWindowLost?(reason)
    }
}
