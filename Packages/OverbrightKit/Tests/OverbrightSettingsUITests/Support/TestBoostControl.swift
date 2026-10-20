// OverbrightSettingsUITests/Support/TestBoostControl.swift — a `BoostControl` for the self-test sheet's tests: it
// records the options of every self-test and, like the engine, runs it until it ends or the awaiting task is
// cancelled (Stop), returning what it "measured". Everything else is a recorded no-op over a fixed status.
import Foundation
import Observation
import OverbrightCore

/// The engine façade with a controllable self-test.
@MainActor @Observable final class TestBoostControl: BoostControl {
    var status: BoostStatus
    /// The options of every `runSelfTest(_:)`, in order.
    private(set) var selfTestOptions: [SelfTestOptions] = []
    /// What a run returns when it ends.
    var report: SelfTestReport
    /// What a cancelled (stopped) run returns.
    var stoppedReport: SelfTestReport
    /// Runs end only when cancelled, or when `endRun()` is called.
    var runsUntilEnded = true
    /// Every other call, in order.
    private(set) var calls: [String] = []
    @ObservationIgnored private var ending: CheckedContinuation<Void, Never>?

    init(fixture: DisplayFixture = .builtinXDRLidOpen, report: SelfTestReport, stoppedReport: SelfTestReport) {
        status = PreviewBoostControl(fixture: fixture).status
        self.report = report
        self.stoppedReport = stoppedReport
    }

    /// Ends the running self-test normally.
    func endRun() {
        ending?.resume()
        ending = nil
    }

    func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport {
        selfTestOptions.append(options)
        guard runsUntilEnded else { return report }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume() } else { ending = continuation }
            }
        } onCancel: {
            Task { @MainActor in self.endRun() }
        }
        return Task.isCancelled ? stoppedReport : report
    }

    func setOn(_ on: Bool, source: ControlSource) { calls.append("setOn") }
    func toggle(source: ControlSource) { calls.append("toggle") }
    func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource) { calls.append("setLevel") }
    func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource) {
        calls.append("setExtraBrightness")
    }
    func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource) { calls.append("setDimLight") }
    func step(_ direction: StepDirection, source: ControlSource) { calls.append("step") }
    func toggleDim(source: ControlSource) { calls.append("toggleDim") }
    func returnToStandard(source: ControlSource) { calls.append("returnToStandard") }
    func keepLevel() { calls.append("keepLevel") }
    func revertLevel() { calls.append("revertLevel") }
    func pause(until deadline: Date?, source: ControlSource) { calls.append("pause") }
    func resume(source: ControlSource) { calls.append("resume") }
    func continueAnyway(_ app: ConflictingApp) { calls.append("continueAnyway") }
    func retry(_ display: DisplayKey) { calls.append("retry") }
    func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? { nil }
    func rescueDisplayColors() async -> RescueOutcome { .alreadyNeutral }
}
