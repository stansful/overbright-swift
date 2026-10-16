// OverbrightSettingsUI/Calibration/PreviewCalibrationSession.swift — a calibration session with in-memory state and no
// display, for the calibration window's #Previews (ARCHITECTURE.md §9.2 rule 3; the preview engine returns no session).
// It records the calls and moves through the states the way the engine's session does, without timing.
import Foundation
import Observation
import OverbrightCore

/// A session for previews.
@Observable final class PreviewCalibrationSession: CalibrationSession {
    let display: DisplayKey
    var currentFactor: Double = 1
    var headroom: Double? = 2.667
    var isSweepPausedAtLimit = false
    var state: CalibrationState = .ready
    private(set) var calls: [String] = []

    init(display: DisplayKey = DisplayFixture.Keys.builtIn, state: CalibrationState = .ready) {
        self.display = display
        self.state = state
    }

    func showComparison(boosted: Bool) { calls.append("showComparison(\(boosted))"); currentFactor = boosted ? 1.116 : 1 }
    func startSweep() { calls.append("startSweep"); state = .sweeping; currentFactor = 1 }
    func continueSweep() { calls.append("continueSweep"); isSweepPausedAtLimit = false }
    func markMerged() { calls.append("markMerged"); state = .swept(mergeFactor: currentFactor, needsConfirmation: false) }
    func showLinearConfirmation() { calls.append("showLinearConfirmation"); state = .confirming }
    func answerLinearConfirmation(distinguishable: Bool) { calls.append("answer(\(distinguishable))") }
    func setMeasuredSDRWhite(nits: Double?) { calls.append("sdrWhite(\(nits.map { "\($0)" } ?? "nil"))") }
    func finish(brighter: Bool?) -> CalibrationRecord? {
        calls.append("finish(\(brighter.map { "\($0)" } ?? "nil"))")
        state = .finished
        return nil
    }
    func cancel() { calls.append("cancel"); state = .aborted(.cancelled) }
}
