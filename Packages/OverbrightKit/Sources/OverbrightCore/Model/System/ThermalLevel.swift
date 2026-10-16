// OverbrightCore/Model/System/ThermalLevel.swift — the thermal state, mirrored. ARCHITECTURE.md §3.3, D10.

/// `ProcessInfo.ThermalState`, mirrored so Core and Policy stay testable without Foundation's class.
public nonisolated enum ThermalLevel: Int, Codable, Sendable, Comparable {
    /// No thermal pressure.
    case nominal
    /// Slightly elevated.
    case fair
    /// Serious: extra brightness is capped at ×1.2.
    case serious
    /// Critical: extra brightness stops.
    case critical
    /// Hotter levels sort later.
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}
