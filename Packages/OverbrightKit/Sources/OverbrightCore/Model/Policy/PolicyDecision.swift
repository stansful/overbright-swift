// OverbrightCore/Model/Policy/PolicyDecision.swift — the reducer's output. ARCHITECTURE.md §3.4, §6.

/// The reducer's output: one decision per display plus the global banner and symbol.
public nonisolated struct PolicyDecision: Hashable, Sendable {
    /// Decisions by display.
    public var displays: [DisplayKey: DisplayDecision]
    /// The panel's banner, if any.
    public var banner: Banner?
    /// The menu bar symbol.
    public var symbol: StatusSymbolState
    /// A decision.
    public init(displays: [DisplayKey: DisplayDecision], banner: Banner?, symbol: StatusSymbolState) {
        self.displays = displays; self.banner = banner; self.symbol = symbol
    }
}
