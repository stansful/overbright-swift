// OverbrightSettingsUI/Panes/PaneWords.swift — words the panes share with Settings' infrastructure: the search terms of
// DESIGN.md §7.2 ("HDR", "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "OLED",
// "flicker", "colors", "quit") that rows carry as well as their panes, and the common buttons. One key keeps one
// comment, so each word here is written exactly as `KnownPaneKeywords` and the components write it.
import Foundation

/// Shared words of the panes.
enum PaneWords {
    static var login: String {
        String(localized: "login", bundle: .module, comment: "Settings search: keyword that finds the General pane (opening at login)")
    }
    static var quit: String {
        String(localized: "quit", bundle: .module, comment: "Settings search: keyword that finds the General pane (Quit Overbright)")
    }
    static var menuBar: String {
        String(localized: "menu bar", bundle: .module, comment: "Settings search: keyword that finds the General pane (the menu bar icon)")
    }
    static var hdr: String {
        String(localized: "HDR", bundle: .module, comment: "Settings search: keyword that finds the Displays pane")
    }
    static var xdr: String {
        String(localized: "XDR", bundle: .module, comment: "Settings search: keyword that finds the Displays pane")
    }
    static var nits: String {
        String(localized: "nits", bundle: .module, comment: "Settings search: keyword that finds the Displays pane (the unit of luminance)")
    }
    static var brighter: String {
        String(localized: "brighter", bundle: .module, comment: "Settings search: keyword that finds the Displays pane")
    }
    static var dim: String {
        String(localized: "dim", bundle: .module, comment: "Settings search: keyword that finds the Displays pane (dim below minimum)")
    }
    static var oled: String {
        String(localized: "OLED", bundle: .module, comment: "Settings search: keyword that finds the Displays pane")
    }
    static var brightness: String {
        String(localized: "brightness", bundle: .module, comment: "Settings search: keyword that finds the Displays pane")
    }
    static var battery: String {
        String(localized: "battery", bundle: .module, comment: "Settings search: keyword that finds the Automations pane")
    }
    static var timer: String {
        String(localized: "timer", bundle: .module, comment: "Settings search: keyword that finds the Automations pane (Turn off after)")
    }
    static var fullScreen: String {
        String(localized: "full screen", bundle: .module,
               comment: "Settings search: keyword that finds the Automations pane (pause for full-screen video)")
    }
    static var schedule: String {
        String(localized: "schedule", bundle: .module, comment: "Settings search: keyword that finds the Automations pane")
    }
    static var focus: String {
        String(localized: "Focus", bundle: .module,
               comment: "Settings search: keyword that finds the Automations pane (Apple's Focus feature, use its name in your language)")
    }
    static var shortcut: String {
        String(localized: "shortcut", bundle: .module, comment: "Settings search: keyword that finds the Shortcuts pane (a keyboard shortcut)")
    }
    static var controlCenter: String {
        String(localized: "Control Center", bundle: .module,
               comment: "Settings search: keyword that finds the Shortcuts pane (Apple's Control Center, use its name in your language)")
    }
    static var camera: String {
        String(localized: "camera", bundle: .module, comment: "Settings search: keyword that finds the Fill Light pane")
    }
    static var flicker: String {
        String(localized: "flicker", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane")
    }
    static var colors: String {
        String(localized: "colors", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane (Reset Display Colors)")
    }
    static var diagnostics: String {
        String(localized: "diagnostics", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane")
    }
    static var selfTest: String {
        String(localized: "self-test", bundle: .module, comment: "Settings search: keyword that finds the Advanced pane")
    }

    /// "Cancel": every confirmation's cancel button.
    static var cancel: String {
        String(localized: "Cancel", bundle: .module, comment: "Settings: cancel button of a confirmation (title case)")
    }
}
