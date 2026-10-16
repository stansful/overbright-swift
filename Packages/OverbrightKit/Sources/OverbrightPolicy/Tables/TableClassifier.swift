// OverbrightPolicy/Tables/TableClassifier.swift — classifies a read table against the expected base. ARCHITECTURE.md
// §3.10, §4.8, D26. Stub until WP1.
import OverbrightCore

/// D26: classifies a read table against the display's expected (profile) base. Never uses the table maximum.
/// `.scaled` = a uniform ratio ≥ 1.02 or ≤ 0.98 at sub-1 sample indices on all channels, or a plateau of ≥ 2 entries
/// ≥ 0.9995 before the last index where the base has none; `.invalid` = not monotonic or all ≈ 0; else `.foreign`.
public nonisolated enum TableClassifier {
    /// The class of `read` against `expectedBase`.
    public static func classify(_ read: GammaTable, expectedBase: GammaTable) -> TableClass {
        _ = (read, expectedBase)
        return .matchesBase   // WP1
    }
    /// Post-restore check (§7.4): monotonic, first entry ≤ 0.1 and last ≥ 0.9, or `matchesBase`.
    public static func isPlausibleRestore(_ read: GammaTable, expectedBase: GammaTable) -> Bool {
        _ = (read, expectedBase)
        return true   // WP1
    }
}
