// OverbrightCore/Model/Policy/BatteryGuard.swift — the battery automation. ARCHITECTURE.md §3.4, D10.

/// When extra brightness pauses on battery.
public nonisolated enum BatteryGuard: String, Codable, Sendable, CaseIterable {
    /// Default: pause extra brightness on battery below `batteryThreshold`.
    case belowThreshold
    /// Pause whenever on battery.
    case onlyOnAdapter
    /// Keep boosting on battery.
    case off
}
