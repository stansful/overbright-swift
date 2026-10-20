// OverbrightCore/Settings/Keys/DisplaySettings.swift — Settings ▸ Displays. ARCHITECTURE.md §3.8, §5.3, §5.4.

/// Settings ▸ Displays.
public nonisolated enum DisplaySettings {
    /// Per-display preferences by display UUID (the same dictionary-by-UUID pattern as Cranny).
    public static let perDisplay = SettingKey(.displays, "perDisplay", default: [DisplayKey: DisplayPreferences]())
    /// "Same level on all displays".
    public static let linkLevels = SettingKey(.displays, "linkLevels", default: false)
    /// The level used for every display while `linkLevels` is on.
    public static let linkedLevel = SettingKey(.displays, "linkedLevel", default: LevelPreset.brightRoom.position)
    /// The dim level of "Dim All Displays", the Dim shortcut and the menu's "Dimmed", as LIGHT (0.02…0.99).
    public static let lastDimLight = SettingKey(.displays, "lastDimLight", default: 0.25)
    /// "Add extra brightness only near full brightness" (§5.4).
    public static let boostOnlyNearFullBrightness = SettingKey(.displays, "boostOnlyNearFullBrightness", default: false)
}
