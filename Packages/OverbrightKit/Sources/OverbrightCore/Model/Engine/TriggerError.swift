// OverbrightCore/Model/Engine/TriggerError.swift — why a trigger could not be made. ARCHITECTURE.md §3.5.

/// Why `TriggerFactory` could not make a trigger.
public nonisolated enum TriggerError: Error, Hashable, Sendable {
    /// The strategy needs this macOS major version.
    case needsNewerMacOS(Int)
    /// The extended-range colour could not be made.
    case colorUnavailable
    /// No Metal device drives the display.
    case noMetalDevice
    /// The display is gone.
    case displayGone
}
