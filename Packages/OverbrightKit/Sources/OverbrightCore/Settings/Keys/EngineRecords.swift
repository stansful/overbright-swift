// OverbrightCore/Settings/Keys/EngineRecords.swift — engine records (not preferences). ARCHITECTURE.md §3.8, §8.2, D7.

/// Records, not preferences: excluded from Reset All.
public nonisolated enum EngineRecords {
    /// Diagnostic marker written while any display is scaled or dimmed (D7). Present at launch + every table
    /// `matchesBase` means "we died and WindowServer restored"; present + a `scaled` table means "run the rescue".
    public static let boostMarker = SettingKey(.engine, "boostMarker", default: BoostMarker?.none)
    /// The last directive of the Focus filter, written by Signals and read at launch together with
    /// `OverbrightFocusFilter.current` (ARCHITECTURE.md §8.2).
    public static let focusDirective = SettingKey(.engine, "focusDirective", default: FocusDirective.leaveAlone)
}
