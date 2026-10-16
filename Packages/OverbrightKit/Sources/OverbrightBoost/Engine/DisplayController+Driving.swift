// OverbrightBoost/Engine/DisplayController+Driving.swift — the seam the self-test and the calibration drive.
// ARCHITECTURE.md §4.1, §8.4, §10.0 (`DisplayControllerDriving`, owned by the contract owner). The engine has returned
// every display to Standard before it hands a controller out; nothing here writes a table except through
// `TableWriter`. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController: DisplayControllerDriving {
    /// The display driven.
    var display: DisplayRef { ref }

    /// Shows one rung with the table at its baseline (the self-test measures triggers only). The baseline is captured
    /// afresh, so a calibration never multiplies a curve from before a profile or preset change.
    func arm(rung request: TriggerRequest) async -> Bool {
        generation += 1
        let stamp = generation
        cancelAllTasks()
        refreshBaseline()
        let handle: any TriggerHandle
        do {
            handle = try deps.triggers.makeTrigger(request, on: ref)
        } catch {
            return false
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
    /// while the display was idle. Kept while our own scaled write is still on the table (it is what a landing
    /// restores). A rejected or failed read leaves no baseline, so a calibration write is refused.
    @discardableResult
    func refreshBaseline() -> Bool {
        guard mechanism == .table, facts.gammaCapacity > 0, !isScaledOrDimmed, !lastWriteIsScaled else {
            return baseline != nil
        }
        baseline = nil
        return captureBaseline(failsOnReject: false)
    }

    /// Calibration only: `factor` × the baseline through `TableWriter.writeCalibrationFactor`, which refuses anything
    /// above `maxFactor` or the live interlock.
    func writeCalibrationFactor(_ factor: Double, maxFactor: Double) throws {
        guard !isOffConsole, parameters.isSessionActive else { throw GammaError.writeRefused }
        if baseline == nil, !captureBaseline(failsOnReject: false) { throw GammaError.writeRefused }
        guard let baseline, let reading = takeReading() else { throw GammaError.writeRefused }
        deps.ledger.markScaled(ref, baseline: baseline)
        try deps.writer.writeCalibrationFactor(factor, to: ref, reading: reading, maxFactor: maxFactor)
        lastWrite = (baseline, factor)
        appliedFactor = factor
        appliedGain = FactorMath.lightGain(forTableFactor: factor, domain: .encoded)
        notify()
    }
}
