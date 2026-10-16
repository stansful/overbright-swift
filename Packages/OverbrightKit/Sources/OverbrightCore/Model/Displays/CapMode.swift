// OverbrightCore/Model/Displays/CapMode.swift — the ceiling the boost half reaches. ARCHITECTURE.md §3.2, §5.3, D15.

/// The ceiling the boost half reaches (D15 "cap mode"; the UI calls the second one "Peak").
public nonisolated enum CapMode: String, Codable, Sendable, CaseIterable {
    /// The full-screen sustained level (Apple XDR 1000 nits; other HDR min(1000, 0.6 × peak); OLED ×1.3).
    case safe
    /// Up to 0.97 × the headroom macOS grants.
    case peak
}
