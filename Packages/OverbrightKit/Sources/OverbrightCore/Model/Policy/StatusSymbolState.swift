// OverbrightCore/Model/Policy/StatusSymbolState.swift — the menu bar symbol state. ARCHITECTURE.md §3.4, §6.4; DESIGN.md §4.1.

/// Menu bar symbol state (DESIGN.md §4.1).
public nonisolated enum StatusSymbolState: String, Sendable, CaseIterable {
    /// Master off.
    case off
    /// Boosting.
    case on
    /// A requested boost waits for headroom.
    case preparing
    /// Dimming only.
    case dimming
    /// Paused by the user or a guard.
    case paused
    /// Something needs the user's attention.
    case attention
}
