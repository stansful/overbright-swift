// OverbrightIntentsTests/Support/Verdicts.swift — gives fixture statuses the verdicts and targets the router and the
// publisher read (`PreviewBoostControl(fixture:)` starts with no decision, i.e. "not known yet").
import OverbrightCore

/// A verdict on which the boost half may be used.
let supported = DisplayVerdict.supported(safeGain: 1.6, peakGain: 2.667)

/// A policy decision for `key`: `verdict`, and `target` (Standard by default).
func decision(_ key: DisplayKey, verdict: DisplayVerdict, target: BoostTarget = .neutral) -> DisplayDecision {
    let eligibility = EligibilityResult(verdict: verdict, advisories: [], defaultBoostEnabled: verdict.allowsBoost,
                                        defaultMechanism: .table)
    return DisplayDecision(key: key, target: target, reasons: [], eligibility: eligibility, mechanism: .table,
                           domain: .encoded, requestedGain: 1)
}

extension PreviewBoostControl {
    /// Sets the decision of the display `key`.
    func decide(_ key: DisplayKey, verdict: DisplayVerdict, target: BoostTarget = .neutral) {
        guard let index = status.displays.firstIndex(where: { $0.key == key }) else { return }
        status.displays[index].decision = decision(key, verdict: verdict, target: target)
    }
}
