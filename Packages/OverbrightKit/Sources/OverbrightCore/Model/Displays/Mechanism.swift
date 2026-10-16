// OverbrightCore/Model/Displays/Mechanism.swift — what turns headroom into brightness. ARCHITECTURE.md §3.2, §7.5, D4.

/// The mechanism that turns headroom into brightness for a display.
public nonisolated enum Mechanism: String, Codable, Sendable {
    /// EDR trigger + scaled transfer table (default).
    case table
    /// Compatibility mode: full-screen EDR overlay with multiply compositing (technique C).
    case overlay
}
