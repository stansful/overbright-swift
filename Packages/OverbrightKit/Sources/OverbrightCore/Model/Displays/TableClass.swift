// OverbrightCore/Model/Displays/TableClass.swift — what a read table is against the expected base. ARCHITECTURE.md §3.2, D26.

/// What a read table is, compared with the display's expected base (Policy `TableClassifier`, D26).
public nonisolated enum TableClass: Hashable, Sendable {
    /// The table equals the display's profile base (within tolerance).
    case matchesBase
    /// Every channel ≈ base × ratio at sub-1 sample indices (ratio ≥ 1.02 or ≤ 0.98), or a clamped plateau
    /// (≥ 2 entries ≥ 0.9995 before the last index where the base has none; ratio then unknown).
    case scaled(ratio: Double?)
    /// Neither: a per-channel curve (warm-light tool, calibration loader, accessibility filter).
    case foreign
    /// Not monotonic, a channel all ≈ 0 (e.g. an all-zero table from a failed restore), or black lifted above 0.1
    /// where the base starts below it. "Ends ≥ 0.9" is not part of it (a dimmed table ends lower): only the
    /// post-restore check `TableClassifier.isPlausibleRestore` asks for it (§7.4).
    case invalid
}
