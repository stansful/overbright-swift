// OverbrightSettingsUI/Search/KnownPaneKeywords.swift — search terms that find a whole pane (DESIGN.md §7.2: "HDR",
// "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "OLED", "flicker", "colors", "quit").
// Ported from Cranny's KnownPaneKeywords (the owner's MIT code). Rows add their own keywords (`SettingsRowInfo`); these
// make a pane findable by what people call its subject, in their language.
import Foundation

/// Keywords per pane.
enum KnownPaneKeywords {
    /// Every pane's keywords, localized.
    static var all: [SettingsPaneID: [String]] {
        [
            .general: [
                String(localized: "login", bundle: .module, comment: "Settings search: keyword that finds the General pane (opening at login)"),
                String(localized: "quit", bundle: .module, comment: "Settings search: keyword that finds the General pane (Quit Overbright)"),
                String(localized: "menu bar", bundle: .module, comment: "Settings search: keyword that finds the General pane (the menu bar icon)"),
                String(localized: "updates", bundle: .module, comment: "Settings search: keyword that finds the General pane (update check)"),
            ],
            .displays: [
                String(localized: "HDR", bundle: .module, comment: "Settings search: keyword that finds the Displays pane"),
                String(localized: "XDR", bundle: .module, comment: "Settings search: keyword that finds the Displays pane"),
                String(localized: "nits", bundle: .module, comment: "Settings search: keyword that finds the Displays pane (the unit of luminance)"),
                String(localized: "brighter", bundle: .module, comment: "Settings search: keyword that finds the Displays pane"),
                String(localized: "dim", bundle: .module, comment: "Settings search: keyword that finds the Displays pane (dim below minimum)"),
                String(localized: "OLED", bundle: .module, comment: "Settings search: keyword that finds the Displays pane"),
                String(localized: "brightness", bundle: .module, comment: "Settings search: keyword that finds the Displays pane"),
            ],
            .automations: [
                String(localized: "battery", bundle: .module, comment: "Settings search: keyword that finds the Automations pane"),
                String(localized: "timer", bundle: .module, comment: "Settings search: keyword that finds the Automations pane (Turn off after)"),
                String(localized: "full screen", bundle: .module, comment: "Settings search: keyword that finds the Automations pane (pause for full-screen video)"),
                String(localized: "schedule", bundle: .module, comment: "Settings search: keyword that finds the Automations pane"),
                String(localized: "Focus", bundle: .module, comment: "Settings search: keyword that finds the Automations pane (Apple's Focus feature, use its name in your language)"),
            ],
            .shortcuts: [
                String(localized: "shortcut", bundle: .module, comment: "Settings search: keyword that finds the Shortcuts pane (a keyboard shortcut)"),
                String(localized: "keyboard", bundle: .module, comment: "Settings search: keyword that finds the Shortcuts pane"),
                String(localized: "hot key", bundle: .module, comment: "Settings search: keyword that finds the Shortcuts pane"),
                String(localized: "Control Center", bundle: .module, comment: "Settings search: keyword that finds the Shortcuts pane (Apple's Control Center, use its name in your language)"),
            ],
            .fillLight: [
                String(localized: "camera", bundle: .module, comment: "Settings search: keyword that finds the Fill Light pane"),
                String(localized: "video call", bundle: .module, comment: "Settings search: keyword that finds the Fill Light pane"),
                String(localized: "edge light", bundle: .module, comment: "Settings search: keyword that finds the Fill Light pane (a glowing frame around the screen)"),
            ],
            .advanced: [
                String(localized: "flicker", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane"),
                String(localized: "colors", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane (Reset Display Colors)"),
                String(localized: "diagnostics", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane"),
                String(localized: "self-test", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane"),
                String(localized: "reset", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane (Reset All Settings)"),
            ],
            .about: [
                AboutContent.versionKeyword,
                String(localized: "license", bundle: .module, comment: "Settings search: keyword that finds the About pane"),
                String(localized: "privacy", bundle: .module, comment: "Settings search: keyword that finds the About pane"),
                String(localized: "welcome", bundle: .module, comment: "Settings search: keyword that finds the About pane (Show Welcome)"),
            ],
        ]
    }
}
