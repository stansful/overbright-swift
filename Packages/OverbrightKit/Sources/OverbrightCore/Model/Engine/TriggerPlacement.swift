// OverbrightCore/Model/Engine/TriggerPlacement.swift — where a trigger window sits. ARCHITECTURE.md §3.5, §4.7.

/// Where the 1-pt trigger window sits on its display.
public nonisolated enum TriggerPlacement: String, Codable, Sendable {
    /// Top-right corner (default; hidden by the rounded corner on notched built-ins).
    case topRightCorner
    /// Top-left corner.
    case topLeftCorner
    /// Inside the notch band.
    case notch
}
