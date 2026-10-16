// OverbrightCore/Settings/Keys/ShortcutSettings.swift — Settings ▸ Shortcuts. ARCHITECTURE.md §3.8, D17.

/// Settings ▸ Shortcuts.
public nonisolated enum ShortcutSettings {
    /// nil value = the user cleared that shortcut; a missing key = the catalog default.
    public static let bindings = SettingKey(.shortcuts, "bindings", default: [ShortcutID: KeyCombo?]())
    /// Brighter / Less Bright step size.
    public static let stepSize = SettingKey(.shortcuts, "stepSize", default: StepSize.regular)
}
