// OverbrightSettingsUITests/Support/FakeCalibrationSession.swift — a `CalibrationSession` whose state the tests drive,
// recording every call in order, for the calibration window's model (DESIGN.md §9). It applies a comparison only once
// it is ready (as the engine's session does) and returns the record the test sets from `finish(brighter:)`.
import Foundation
import Observation
import OverbrightCore

/// A scripted calibration session.
@MainActor @Observable final class FakeCalibrationSession: CalibrationSession {
    let display: DisplayKey
    var currentFactor: Double = 1
    var headroom: Double? = 2.667
    var isSweepPausedAtLimit = false
    var state: CalibrationState
    /// What `finish(brighter:)` returns (nil: nothing was measured).
    var record: CalibrationRecord?
    /// Every call, in order.
    private(set) var calls: [String] = []
    /// The comparison factor the engine shows for ×1.3 light at H 2.667 in the encoded domain.
    static let comparisonFactor = 1.116

    init(display: DisplayKey = DisplayFixture.Keys.builtIn, state: CalibrationState = .preparing) {
        self.display = display
        self.state = state
    }

    func showComparison(boosted: Bool) {
        calls.append("showComparison(\(boosted))")
        guard state == .ready else { return }
        currentFactor = boosted ? Self.comparisonFactor : 1
    }
    func startSweep() { calls.append("startSweep"); state = .sweeping }
    func continueSweep() { calls.append("continueSweep"); isSweepPausedAtLimit = false }
    func markMerged() { calls.append("markMerged") }
    func showLinearConfirmation() { calls.append("showLinearConfirmation"); state = .confirming }
    func answerLinearConfirmation(distinguishable: Bool) { calls.append("answerLinearConfirmation(\(distinguishable))") }
    func setMeasuredSDRWhite(nits: Double?) { calls.append("setMeasuredSDRWhite(\(nits.map { "\($0)" } ?? "nil"))") }
    func finish(brighter: Bool?) -> CalibrationRecord? {
        calls.append("finish(\(brighter.map { "\($0)" } ?? "nil"))")
        currentFactor = 1
        state = .finished
        return record
    }
    func cancel() {
        calls.append("cancel")
        currentFactor = 1
        state = .aborted(.cancelled)
    }

    /// A record with `outcome` for this display's test.
    static func record(_ outcome: CalibrationRecord.Outcome, mechanism: Mechanism = .table,
                       sdrWhite: Double? = nil) -> CalibrationRecord {
        CalibrationRecord(outcome: outcome, mechanism: mechanism, mergeFactor: outcome == .encoded ? 1.62 : nil,
                          estimatedExponent: nil, measuredSDRWhiteNits: sdrWhite, headroomAtTest: 2.667,
                          potentialAtTest: 16, osBuild: DisplayFixture.ownerMachine.osBuild,
                          measuredAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
    }
}
