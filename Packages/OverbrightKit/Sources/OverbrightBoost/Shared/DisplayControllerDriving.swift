// OverbrightBoost/Shared/DisplayControllerDriving.swift — how the self-test and the calibration drive one display.
// ARCHITECTURE.md §4.1, §8.4, §10.0 (Boost seam). Shared between WP4 (`DisplayController` conforms) and WP5
// (`SelfTestRunner`, `CalibrationController` call it), owned by the contract owner. Neither caller writes a table
// except through `TableWriter`.
import OverbrightCore

/// One display's controller as the self-test and the calibration see it. The engine has already returned every
/// display to Standard (triggers removed, neutral tables) before handing out a driver.
public protocol DisplayControllerDriving: AnyObject {
    /// The display driven.
    var display: DisplayRef { get }
    /// Shows one rung of the ladder with the table at its baseline (the self-test measures triggers only).
    /// Returns false when the rung never presented (T2/T3 after their retries, or the factory threw).
    func arm(rung: TriggerRequest) async -> Bool
    /// A fresh headroom reading of this display (nil for a display without its own NSScreen).
    func readHeadroom() -> HeadroomReading?
    /// Writes the baseline, then removes the trigger (§4.5 invariant 2).
    func disarm() async
    /// Back to Standard at once: baseline written, trigger removed.
    func returnToStandard()
    /// Calibration only: writes `factor` × the baseline through `TableWriter.writeCalibrationFactor`, which refuses
    /// anything above `maxFactor` or the reading's calibration ceiling, a stale reading and a stale hang epoch (WP14:
    /// not the boost interlock's `0.97 × H`, which the sweep must pass; §5.2).
    func writeCalibrationFactor(_ factor: Double, maxFactor: Double) throws
}
