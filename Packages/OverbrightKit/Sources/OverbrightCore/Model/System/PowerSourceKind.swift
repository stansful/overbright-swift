// OverbrightCore/Model/System/PowerSourceKind.swift — where the Mac draws power from. ARCHITECTURE.md §3.3.

/// The power source `SystemSignals` reports (IOPS).
public nonisolated enum PowerSourceKind: String, Codable, Sendable {
    /// AC adapter.
    case adapter
    /// Internal battery.
    case battery
    /// Uninterruptible power supply.
    case ups
    /// Not reported.
    case unknown
}
