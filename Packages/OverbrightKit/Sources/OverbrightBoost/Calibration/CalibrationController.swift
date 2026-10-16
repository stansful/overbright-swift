// OverbrightBoost/Calibration/CalibrationController.swift — one running calibration. ARCHITECTURE.md §5.2, §5.6;
// DESIGN.md §9. Seeded by WP0a with the fixed signatures (§10.0); owned by WP5, which writes the body (comparison,
// sweep with its pause, linear confirmation, decision rule, auto-abort). The WP0a body writes nothing and records
// nothing.
import OverbrightCore

/// Implements `CalibrationSession` for one display; every table write goes through `writer`.
public final class CalibrationController: CalibrationSession {
    /// The display under test.
    public let display: DisplayKey
    /// The table factor shown now.
    public private(set) var currentFactor: Double = 1
    /// The latest headroom of the display.
    public private(set) var headroom: Double?
    /// True while the sweep waits at 1.15 × the encoded prediction for "Keep Going".
    public private(set) var isSweepPausedAtLimit = false

    private let driver: any DisplayControllerDriving
    private let writer: TableWriter
    private let time: any TimeSource
    private let machine: MachineIdentity

    /// A session for `display`, driven through `driver`.
    public init(display: DisplayKey, driver: any DisplayControllerDriving, writer: TableWriter, time: any TimeSource,
                machine: MachineIdentity) {
        self.display = display; self.driver = driver; self.writer = writer; self.time = time; self.machine = machine
    }

    /// WP5.
    public func showComparison(boosted: Bool) { _ = boosted }
    /// WP5.
    public func startSweep() {}
    /// WP5.
    public func continueSweep() {}
    /// WP5.
    public func markMerged() {}
    /// WP5.
    public func showLinearConfirmation() {}
    /// WP5.
    public func answerLinearConfirmation(distinguishable: Bool) { _ = distinguishable }
    /// WP5.
    public func setMeasuredSDRWhite(nits: Double?) { _ = nits }
    /// WP5: no record yet.
    public func finish(brighter: Bool?) -> CalibrationRecord? {
        _ = brighter
        return nil
    }
    /// WP5.
    public func cancel() {}
}
