// OverbrightPolicy/Reducer/BoostPolicy.swift — the pure guard reducer (D10). ARCHITECTURE.md §3.10, §6. Boost takes the
// reducer as an injected function (`BoostEngine(reduce:)`, default `BoostPolicy.reduce`), so engine tests can also run
// against TestSupport's ReferenceReducer.
import OverbrightCore

/// D10: the pure guard reducer. Exhaustively tested; no clocks, no I/O, no randomness (`now`, `minuteOfDay`, the
/// machine and the system snapshot are inputs).
///
/// Per display (§6.1, `DisplayReducer`): eligibility, the effective level (own, linked or Focus), mechanism and
/// domain; then every stop and boost-only guard in precedence order, the first of which sets `.neutral`; otherwise
/// `.neutral` at Standard, `.dim(light:)` on the dim half, or `.boost(gain:)` with the static caps of §5.4 and the
/// reasons that bind. Light gains below ×1.005 are a no-op and stay `.neutral`. Across displays: the banner of
/// §6.3 (`BannerSelector`) and the symbol of §6.4 (`SymbolSelector`; never `.preparing`, which the engine sets).
public nonisolated enum BoostPolicy {
    /// Every display's target and reasons, the banner and the menu bar symbol.
    public static func reduce(_ input: PolicyInput) -> PolicyDecision {
        let reducer = DisplayReducer(input: input)
        let outcomes = input.displays.map(reducer.outcome(for:))
        let banner = BannerSelector.banner(for: outcomes, input: input)
        let symbol = SymbolSelector.symbol(for: outcomes, banner: banner, input: input,
                                           isPaused: reducer.pausedUntil != nil)
        var displays: [DisplayKey: DisplayDecision] = [:]
        for outcome in outcomes where displays[outcome.decision.key] == nil {
            displays[outcome.decision.key] = outcome.decision
        }
        return PolicyDecision(displays: displays, banner: banner, symbol: symbol)
    }
}
