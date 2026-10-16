// OverbrightPolicy/Reducer/SymbolSelector.swift — the menu bar symbol state. ARCHITECTURE.md §6.4; DESIGN.md §4.1.
import OverbrightCore

/// `off` when the master is off; `attention` while a conflict, trip or foreign-table banner is up; `paused` while a
/// user pause runs or every display that should boost is stopped by a global stop or a boost-only guard; `dimming`
/// when every changed display is dimmed; otherwise `on`. `preparing` depends on engine phases the reducer never sees:
/// the engine sets it in `BoostStatus.symbol` while a display that should boost is arming or gating.
nonisolated enum SymbolSelector {
    static func symbol(for outcomes: [DisplayOutcome], banner: Banner?, input: PolicyInput,
                       isPaused: Bool) -> StatusSymbolState {
        guard input.isMasterOn else { return .off }
        if let banner, BannerSelector.isAttention(banner) { return .attention }
        if isPaused { return .paused }
        let boosting = outcomes.filter(\.requestsBoost)
        if !boosting.isEmpty && boosting.allSatisfy(isStoppedByAGuard) { return .paused }
        let changed = outcomes.map(\.decision.target).filter { $0 != .neutral }
        if !changed.isEmpty && changed.allSatisfy({ if case .dim = $0 { true } else { false } }) { return .dimming }
        return .on
    }

    /// Neutral because of a stop that applies to every display (lock and sleep included) or a boost-only guard.
    private static func isStoppedByAGuard(_ outcome: DisplayOutcome) -> Bool {
        outcome.decision.target == .neutral && outcome.decision.reasons.contains { reason in
            reason.isGlobal || reason.blocksBoostOnly || reason == .shielded
        }
    }
}
