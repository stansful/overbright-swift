// OverbrightCore/Model/Displays/MechanismPreference.swift — the user's mechanism choice. ARCHITECTURE.md §3.2, §6.1.

/// The per-display mechanism setting (Advanced); `automatic` lets Policy choose (§6.1 step 4).
public nonisolated enum MechanismPreference: String, Codable, Sendable, CaseIterable {
    /// Overlay on a Mac that ignores table writes or when calibration said "not brighter" (never while the overlay is
    /// unavailable), else table.
    case automatic
    /// Always the transfer table.
    case table
    /// Always the Compatibility-mode overlay.
    case overlay

    /// Whether Compatibility mode (the full-screen multiply overlay, technique C) may be used at all. Off since
    /// 2026-10-20: on the owner's MacBook Pro (M4 Max, macOS 27.0.1) the overlay turned the built-in display white
    /// the moment it boosted, because WindowServer does not blend a window's `multiplyBlendMode` layer with the
    /// windows beneath it. Until a blend that works across windows is proven on hardware, Policy uses the table for
    /// every display, a stored `overlay` preference included; no surface offers a choice (D4, §7.5).
    public static let overlayIsAvailable = false
}
