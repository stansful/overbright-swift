// OverbrightCore/Model/Displays/OLEDOverride.swift — the user's OLED override for a display. ARCHITECTURE.md §3.2, D8.

/// Overrides the IORegistry-based OLED detection of one display (D8).
public nonisolated enum OLEDOverride: String, Codable, Sendable {
    /// Detected from the minimum luminance (≤ 0.005 nits).
    case automatic
    /// Treat as OLED (lower Safe cap, idle pause, black triggers only).
    case oled
    /// Treat as not OLED.
    case notOLED
}
