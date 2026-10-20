// OverbrightCore/Ports/BoostControl.swift — the engine façade (implemented by OverbrightBoost). ARCHITECTURE.md §3.6, §4.9.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Foundation
import Observation

/// What every surface (panel, menu, shortcuts, intents, Settings) asks the engine.
@MainActor public protocol BoostControl: AnyObject, Observable {
    /// Everything the engine publishes.
    var status: BoostStatus { get }
    /// Master on or off.
    func setOn(_ on: Bool, source: ControlSource)
    /// Flips the master switch.
    func toggle(source: ControlSource)
    /// nil display = every display (or the linked level). Moving a slider also turns the master on and ends a pause.
    func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource)
    /// A preset or multiplier on the boost half.
    func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource)
    /// Dim to `light` (0.02…0.99 of Standard light). nil display = every display that can dim.
    func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource)
    /// Brighter / Less Bright, in stops (`StepMath`).
    func step(_ direction: StepDirection, source: ControlSource)
    /// "Dim All Displays" ⇄ "Stop Dimming": every display that can dim goes to `lastDimLight`, or back to its level.
    func toggleDim(source: ControlSource)
    /// Back to Standard: master off within 120 ms, dims undone, stored levels KEPT. Always available.
    func returnToStandard(source: ControlSource)
    /// Confirms a pending "Keep this level?".
    func keepLowLevel()
    /// Reverts a pending "Keep this level?" now.
    func revertLowLevel()
    /// The engine owns the pause deadline (`automations.pausedUntil`) and its single sleep.
    func pause(until deadline: Date?, source: ControlSource)
    /// Ends a pause.
    func resume(source: ControlSource)
    /// S2/S3 only; an S1 booster is never continued (§7.2).
    func continueAnyway(_ app: ConflictingApp)
    /// Try Again: clears any trip on this display (the only way to clear flicker, repair and drift trips).
    func retry(_ display: DisplayKey)
    /// Advanced ▸ Run Self-Test… (master held off, triggers only, never a scaled table).
    func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport
    /// Starts a calibration of `display`; nil when it cannot be calibrated now.
    func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)?
    /// Advanced ▸ Reset Display Colors (dirty-then-restore, D7).
    func rescueDisplayColors() async -> RescueOutcome
    /// Advanced ▸ Forget Learned Methods: clears the strategy cache (the rung each display learned per macOS build,
    /// its failure records and lowest ready headroom, ARCHITECTURE.md §4.7), so the next arm walks the ladder again.
    /// Added through the contract lane (WP11).
    func forgetLearnedMethods()
}

public extension BoostControl {
    /// Nothing is learned (the §10.0 default for a requirement added after WP0a; the engine implements it).
    func forgetLearnedMethods() {}
}
