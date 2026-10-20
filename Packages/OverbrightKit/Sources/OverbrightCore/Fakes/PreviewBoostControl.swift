// OverbrightCore/Fakes/PreviewBoostControl.swift — an in-memory BoostControl for previews and UI tests.
// ARCHITECTURE.md §3.9. PanelUI's `ScriptedStatuses` (WP10) set `status` to every named state of DESIGN.md §5.13.
import Foundation
import Observation

/// A `BoostControl` with in-memory state and recorded calls: no engine, no display, no timer. Tests and previews set
/// `status` directly; the methods record a call ("setOn(true,panel)") and make the obvious change to `status`.
/// Changes from a shortcut, an intent or the Focus filter publish `lastChange` (the HUD's trigger) as the engine does.
@MainActor @Observable public final class PreviewBoostControl: BoostControl {
    /// What the engine would publish (settable).
    public var status: BoostStatus
    /// Every call, in order.
    public private(set) var calls: [String] = []
    /// What `runSelfTest(_:)` returns (nil: an empty report).
    public var selfTestReport: SelfTestReport?
    /// What `rescueDisplayColors()` returns.
    public var rescueOutcome: RescueOutcome = .alreadyNeutral
    /// The Mac named in an empty self-test report.
    public var machine: MachineIdentity
    @ObservationIgnored private var sequence: UInt64 = 0

    /// A control publishing `status`.
    public init(status: BoostStatus = .initial, machine: MachineIdentity = DisplayFixture.ownerMachine) {
        self.status = status; self.machine = machine
    }

    /// Ready and off, with every display of `fixture` idle at Standard.
    public convenience init(fixture: DisplayFixture) {
        let displays = fixture.displays.map { display in
            DisplayStatus(key: display.key, name: display.facts.name, phase: .idle, decision: nil, appliedGain: 1,
                          appliedFactor: 1, mechanism: .table, strategy: nil,
                          lastReading: nil, sdrWhite: nil)
        }
        self.init(status: BoostStatus(isOn: false, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: displays,
                                      banner: nil, symbol: .off),
                  machine: fixture.machine)
    }

    /// Master on or off.
    public func setOn(_ on: Bool, source: ControlSource) {
        record("setOn(\(on),\(source.rawValue))")
        turn(on, source: source)
    }
    /// Flips the master switch.
    public func toggle(source: ControlSource) {
        record("toggle(\(source.rawValue))")
        turn(!status.isOn, source: source)
    }
    /// Records the level; the master turns on and a pause ends.
    public func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource) {
        record("setLevel(\(level.value),\(display?.rawValue ?? "all"),\(source.rawValue))")
        status.pausedUntil = nil
        turn(true, source: source)
    }
    /// Records the request; the master turns on.
    public func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource) {
        let text = switch request {
        case .preset(let preset): preset.rawValue
        case .multiplier(let gain): "×\(gain)"
        }
        record("setExtraBrightness(\(text),\(display?.rawValue ?? "all"),\(source.rawValue))")
        turn(true, source: source)
    }
    /// Records the dim light; the master turns on.
    public func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource) {
        record("setDimLight(\(light),\(display?.rawValue ?? "all"),\(source.rawValue))")
        turn(true, source: source)
    }
    /// Records the step; the master turns on.
    public func step(_ direction: StepDirection, source: ControlSource) {
        record("step(\(direction == .brighter ? "brighter" : "lessBright"),\(source.rawValue))")
        turn(true, source: source)
    }
    /// Records the call.
    public func toggleDim(source: ControlSource) { record("toggleDim(\(source.rawValue))") }
    /// Master off; levels kept.
    public func returnToStandard(source: ControlSource) {
        record("returnToStandard(\(source.rawValue))")
        turn(false, source: source)
    }
    /// Clears the pending confirmation.
    public func keepLowLevel() { record("keepLowLevel"); status.pendingLowLevel = nil }
    /// Clears the pending confirmation.
    public func revertLowLevel() { record("revertLowLevel"); status.pendingLowLevel = nil }
    /// Sets `pausedUntil`.
    public func pause(until deadline: Date?, source: ControlSource) {
        record("pause(\(deadline.map { "\($0.timeIntervalSinceReferenceDate)" } ?? "indefinitely"),\(source.rawValue))")
        status.pausedUntil = deadline
        status.symbol = .paused
    }
    /// Clears `pausedUntil`.
    public func resume(source: ControlSource) {
        record("resume(\(source.rawValue))")
        status.pausedUntil = nil
        status.symbol = status.isOn ? .on : .off
    }
    /// Records the entry.
    public func continueAnyway(_ app: ConflictingApp) { record("continueAnyway(\(app.entryID))") }
    /// Records the display.
    public func retry(_ display: DisplayKey) { record("retry(\(display.rawValue))") }
    /// `selfTestReport`, or an empty report.
    public func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport {
        record("runSelfTest(everyStrategy:\(options.everyStrategy))")
        return selfTestReport ?? SelfTestReport(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                                                machine: machine, appVersion: "0.1.0", displays: [:], journal: [])
    }
    /// No calibration in previews.
    public func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? {
        record("beginCalibration(\(display.rawValue))")
        return nil
    }
    /// `rescueOutcome`.
    public func rescueDisplayColors() async -> RescueOutcome {
        record("rescueDisplayColors")
        return rescueOutcome
    }
    /// Records the call.
    public func forgetLearnedMethods() { record("forgetLearnedMethods") }

    private func record(_ call: String) { calls.append(call) }

    private func turn(_ on: Bool, source: ControlSource) {
        status.isOn = on
        if status.pausedUntil == nil { status.symbol = on ? .on : .off }
        guard [.shortcut, .intent, .focusFilter].contains(source) else { return }
        sequence += 1
        status.lastChange = LevelChange(sequence: sequence, kind: .level, source: source, display: nil)
    }
}
