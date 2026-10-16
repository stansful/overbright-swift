// OverbrightCore/Settings/Keys/GeneralSettings.swift — Settings ▸ General. ARCHITECTURE.md §3.8; DESIGN.md §7.

/// Settings ▸ General.
public nonisolated enum GeneralSettings {
    /// What happens at login (default: open, keep off).
    public static let launchBehavior = SettingKey(.general, "launchBehavior", default: LaunchBehavior.launchOnly)
    /// The status item is shown.
    public static let showsMenuBarIcon = SettingKey(.general, "showsMenuBarIcon", default: true)
    /// What a click on the status item does.
    public static let clickAction = SettingKey(.general, "clickAction", default: StatusClickAction.openPanel)
    /// The HUD shows level changes and automatic stops.
    public static let showsHUD = SettingKey(.general, "showsHUD", default: true)
    /// Trackpad haptics at the slider's detent and ticks.
    public static let haptics = SettingKey(.general, "haptics", default: true)
    /// Shows a Dock icon (activation policy .regular) with a Dock menu. Off: a pure menu bar app.
    public static let showsDockIcon = SettingKey(.general, "showsDockIcon", default: false)
}
