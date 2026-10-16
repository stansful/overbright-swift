// OverbrightCore/Model/Displays/GammaError.swift — failures of the GammaPort. ARCHITECTURE.md §3.2, §4.5.

/// Why a `GammaPort` call failed.
public nonisolated enum GammaError: Error, Hashable, Sendable {
    /// Capacity 0 (virtual display).
    case noTable
    /// A `CGError` raw value.
    case coreGraphics(code: Int32)
    /// The ID is no longer online.
    case displayGone
    /// The interlock refused a scaled write (stale epoch, stale or foreign reading).
    case writeRefused
}
