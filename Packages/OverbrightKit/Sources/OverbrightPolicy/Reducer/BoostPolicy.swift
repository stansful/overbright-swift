// OverbrightPolicy/Reducer/BoostPolicy.swift — the pure guard reducer (D10). ARCHITECTURE.md §3.10, §6. Stub until WP1;
// Boost takes the reducer as an injected function, so WP4 tests against TestSupport's ReferenceReducer meanwhile.
import OverbrightCore

/// D10: the pure guard reducer. Exhaustively tested; no clocks, no I/O, no randomness.
public nonisolated enum BoostPolicy {
    /// Every display's target and reasons, the banner and the menu bar symbol.
    public static func reduce(_ input: PolicyInput) -> PolicyDecision {
        _ = input
        return PolicyDecision(displays: [:], banner: nil, symbol: .off)   // WP0a stub: everything neutral
    }
}
