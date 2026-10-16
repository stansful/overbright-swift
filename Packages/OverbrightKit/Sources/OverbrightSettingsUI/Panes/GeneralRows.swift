// OverbrightSettingsUI/Panes/GeneralRows.swift — the rows of Settings ▸ General (DESIGN.md §7.3), shared by the pane
// (labels) and the search index (labels and localized keywords). Row ids are deep-link names ("general#quit").
import Foundation
import OverbrightCore

/// The rows of Settings ▸ General.
enum GeneralRows {
    /// The warning row while the menu bar icon cannot be seen (DESIGN.md §4.4).
    static var iconWarning: SettingsRowInfo {
        SettingsRowInfo(.general, "iconWarning",
                        title: String(localized: "Overbright’s icon isn’t visible.", bundle: .module,
                                      comment: "Settings ▸ General: warning row while the menu bar icon cannot be seen"),
                        keywords: [PaneWords.menuBar,
                                   String(localized: "hidden", bundle: .module, comment: "Settings search: keyword for the icon warning")])
    }

    static var launchBehavior: SettingsRowInfo {
        SettingsRowInfo(.general, "launchBehavior",
                        title: String(localized: "When you log in", bundle: .module,
                                      comment: "Settings ▸ General: what Overbright does at login (radio group)"),
                        keywords: [PaneWords.login,
                                   String(localized: "startup", bundle: .module, comment: "Settings search: keyword for When you log in"),
                                   String(localized: "restart", bundle: .module, comment: "Settings search: keyword for When you log in")])
    }

    static var menuBarIcon: SettingsRowInfo {
        SettingsRowInfo(.general, "menuBarIcon",
                        title: String(localized: "Show menu bar icon", bundle: .module, comment: "Settings ▸ General: switch"),
                        keywords: [PaneWords.menuBar,
                                   String(localized: "hide", bundle: .module, comment: "Settings search: keyword for Show menu bar icon")])
    }

    static var clickAction: SettingsRowInfo {
        SettingsRowInfo(.general, "clickAction",
                        title: String(localized: "Clicking the icon", bundle: .module,
                                      comment: "Settings ▸ General: what a click on the menu bar icon does (segmented)"),
                        keywords: [String(localized: "click", bundle: .module, comment: "Settings search: keyword for Clicking the icon"),
                                   String(localized: "panel", bundle: .module, comment: "Settings search: keyword for Clicking the icon")])
    }

    static var dockIcon: SettingsRowInfo {
        SettingsRowInfo(.general, "dockIcon",
                        title: String(localized: "Show in Dock", bundle: .module, comment: "Settings ▸ General: switch (“Dock” is macOS’s own name)"))
    }

    static var quit: SettingsRowInfo {
        SettingsRowInfo(.general, "quit",
                        title: String(localized: "Quit Overbright", bundle: .module,
                                      comment: "Settings ▸ General: push button that quits the app (title case)"),
                        keywords: [PaneWords.quit,
                                   String(localized: "exit", bundle: .module, comment: "Settings search: keyword for Quit Overbright")])
    }

    static var showsHUD: SettingsRowInfo {
        SettingsRowInfo(.general, "showsHUD",
                        title: String(localized: "Show level changes on screen", bundle: .module, comment: "Settings ▸ General: switch"),
                        keywords: [String(localized: "indicator", bundle: .module, comment: "Settings search: keyword for Show level changes on screen")])
    }

    static var haptics: SettingsRowInfo {
        SettingsRowInfo(.general, "haptics",
                        title: String(localized: "Haptic feedback", bundle: .module, comment: "Settings ▸ General: switch"),
                        keywords: [String(localized: "trackpad", bundle: .module, comment: "Settings search: keyword for Haptic feedback")])
    }
}
