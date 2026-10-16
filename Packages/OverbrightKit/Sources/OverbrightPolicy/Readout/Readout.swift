// OverbrightPolicy/Readout/Readout.swift — builds a card's readout numbers. ARCHITECTURE.md §3.10, §5.5, §6.2;
// DESIGN.md §5.6. Pure numbers only: Design formats them (multipliers, "≈", nits rounded to 5, the dim percentage).
import Foundation
import OverbrightCore

/// Builds `ReadoutValues` from a display's status: what is on screen now, never what the level would ask for.
public nonisolated enum Readout {
    /// An applied gain within this distance of 1 reads as Standard (a no-op boost, a dim ramp's last step).
    public static let standardBand = 0.005
    /// The applied gain must be this far below the request for "asked ×…" (a steady limit, not a rounding).
    public static let limitedMargin = 0.005

    /// The readout numbers of one display.
    ///
    /// - `state`: `.off` while the master is off; `.preparing` while arming or gating; else `.dim`, `.boost` or
    ///   `.standard` by the applied gain.
    /// - `requestedGain`: the decision's request, only while steadily boosted below it ("×1.21 · asked ×1.47").
    /// - `nits`: applied gain × the trusted SDR white, only with a valid calibration record (no `notCalibrated`).
    /// - `preset`: the shown preset at the decision's level, only while boosting and not limited (DESIGN.md's limited
    ///   readout names no preset); hidden presets (`PresetVisibility`) are never named.
    /// - `isEstimate`: no valid calibration (or no decision yet).
    /// - `dimPercent`: the applied light in percent of Standard, 2…99, while dimmed.
    public static func values(for status: DisplayStatus, isMasterOn: Bool) -> ReadoutValues {
        let applied = status.appliedGain
        let decision = status.decision
        let calibrated = decision.map { decision in
            decision.eligibility.verdict.allowsBoost && !decision.eligibility.advisories.contains(.notCalibrated)
        } ?? false
        let state = state(of: status, isMasterOn: isMasterOn)
        guard state == .boost else {
            let dimPercent = state == .dim ? min(max(Int((applied * 100).rounded()), 2), 99) : nil
            return ReadoutValues(state: state, appliedGain: applied, requestedGain: nil, nits: nil, preset: nil,
                                 isEstimate: !calibrated, dimPercent: dimPercent)
        }
        var requested: Double?
        if status.phase == .boosted, let asked = decision?.requestedGain, asked > applied * (1 + limitedMargin) {
            requested = asked
        }
        let nits = calibrated ? status.sdrWhite.map { applied * $0.nits } : nil
        let preset = requested == nil ? decision.flatMap(shownPreset) : nil
        return ReadoutValues(state: .boost, appliedGain: applied, requestedGain: requested, nits: nits, preset: preset,
                             isEstimate: !calibrated, dimPercent: nil)
    }

    private static func state(of status: DisplayStatus, isMasterOn: Bool) -> ReadoutValues.State {
        guard isMasterOn else { return .off }
        switch status.phase {
        case .arming, .gating: return .preparing
        default:
            if status.appliedGain < 1 - standardBand { return .dim }
            if status.appliedGain > 1 + standardBand { return .boost }
            return .standard
        }
    }

    /// The preset at the decision's level, if that preset is shown on this display. The display's top is recovered
    /// from the request (`requestedGain = top ^ p`), so no facts are needed.
    private static func shownPreset(_ decision: DisplayDecision) -> LevelPreset? {
        let level = decision.level
        guard level.isBoost, let preset = LevelMapping.preset(at: level), preset != .standard,
              decision.requestedGain >= 1 else { return nil }
        let top = pow(decision.requestedGain, 1 / level.value)
        return PresetVisibility.visiblePresets(top: top).contains(preset) ? preset : nil
    }
}
