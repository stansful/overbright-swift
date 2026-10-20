// OverbrightPanelUI/Panel/SettingsLinks.swift — where the panel's, the menu's and the chips' actions open Settings and
// System Settings. DESIGN.md §12.2 ("Action destinations"), §12.3, §16 ("Destinations are unambiguous"); the
// "pane#row" deep links of `AppControl.openSettings(_:)` (Cranny's). The pane and row names are the ones WP11's
// Settings window resolves; one table here so no caller spells a link twice.
import Foundation
import OverbrightCore

/// Deep links into Overbright's Settings ("pane" or "pane#row") and the System Settings panes the copy names.
public nonisolated enum SettingsLinks {
    /// Settings ▸ Displays ▸ Add extra brightness only near full brightness ("Change setting…").
    public static let nearFullBrightness = "displays#nearFullBrightness"
    /// Settings ▸ Automations ▸ Power ("Change power rules…").
    public static let powerRules = "automations#power"
    /// Settings ▸ Automations ▸ Apps and video ("Change rules…").
    public static let appRules = "automations#apps"
    /// Settings ▸ Automations ▸ the paused-apps list ("Edit apps…", "Edit Apps…").
    public static let pausedApps = "automations#pausedApps"
    /// Settings ▸ Automations ▸ Schedule ("Change hours…").
    public static let schedule = "automations#schedule"
    /// Settings ▸ Advanced ▸ Run Self-Test… (the sheet opens there).
    public static let selfTest = "advanced#selfTest"
    /// Settings ▸ Shortcuts at the Back to Standard recorder (Welcome's Find it step while no shortcut is recorded).
    public static let backToStandardShortcut = "shortcuts#shortcut.\(ShortcutID.standard.rawValue)"

    /// Settings ▸ Displays at `display`'s section ("Settings for This Display…").
    public static func display(_ display: DisplayKey) -> String { "displays#\(display.rawValue)" }

    /// Settings ▸ Displays at `display`'s Limit row ("Choose Peak…").
    public static func limit(of display: DisplayKey) -> String { "displays#\(display.rawValue).limit" }

    /// System Settings ▸ Displays (verdict fixes, "Open System Settings" of the foreign-table banner).
    public static let systemDisplays = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")
    /// System Settings ▸ Focus (the Focus banner's "Open System Settings").
    public static let systemFocus = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")
    /// System Settings ▸ Menu Bar (the icon-not-visible window, macOS 26 and later).
    public static let systemMenuBar = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")
}
