// OverbrightCore/Model/Displays/MechanismPreference.swift — the user's mechanism choice. ARCHITECTURE.md §3.2, §6.1.

/// The per-display mechanism setting (Advanced); `automatic` lets Policy choose (§6.1 step 4).
public nonisolated enum MechanismPreference: String, Codable, Sendable, CaseIterable {
    /// Overlay when Compatibility mode is advised or calibration said "not brighter", else table.
    case automatic
    /// Always the transfer table.
    case table
    /// Always the Compatibility-mode overlay.
    case overlay
}
