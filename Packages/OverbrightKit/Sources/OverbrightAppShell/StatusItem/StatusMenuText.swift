// OverbrightAppShell/StatusItem/StatusMenuText.swift — the status item's and its menu's own words (the StatusMenu
// table, ARCHITECTURE.md §8.8). DESIGN.md §4.1 (VoiceOver labels), §4.3 (exact English, title case), §12.3 (the
// banner actions in title case), §12.7, §12.9 (announcements). The display rows' quick levels are PanelUI's.
import Foundation
import OverbrightCore

/// Copy of the status item and its menu.
enum StatusMenuText {
    // MARK: Status item

    /// The status item's VoiceOver label in `state` (DESIGN.md §4.1, exact).
    static func symbolLabel(_ state: StatusSymbolState) -> String {
        switch state {
        case .off: String(localized: "Overbright, off", table: "StatusMenu", bundle: .module,
                          comment: "VoiceOver: the status item while Overbright is off")
        case .on: String(localized: "Overbright, on", table: "StatusMenu", bundle: .module,
                         comment: "VoiceOver: the status item while Overbright is on")
        case .preparing: String(localized: "Overbright, preparing", table: "StatusMenu", bundle: .module,
                                comment: "VoiceOver: the status item while a display waits for extra range")
        case .dimming: String(localized: "Overbright, dimmed", table: "StatusMenu", bundle: .module,
                              comment: "VoiceOver: the status item while displays are dimmed")
        case .paused: String(localized: "Overbright, paused", table: "StatusMenu", bundle: .module,
                             comment: "VoiceOver: the status item while extra brightness is paused")
        case .attention: String(localized: "Overbright, needs attention", table: "StatusMenu", bundle: .module,
                                comment: "VoiceOver: the status item while a conflict or a stop needs the user")
        }
    }

    /// "Overbright on" / "Overbright off" after a click on the icon toggled it.
    static func announcement(isOn: Bool) -> String {
        isOn ? String(localized: "Overbright on", table: "StatusMenu", bundle: .module,
                      comment: "VoiceOver: announced after turning Overbright on from the icon or a shortcut")
            : String(localized: "Overbright off", table: "StatusMenu", bundle: .module,
                     comment: "VoiceOver: announced after turning Overbright off from the icon or a shortcut")
    }

    // MARK: Menu rows (title case)

    static var showPanel: String {
        String(localized: "Show Panel", table: "StatusMenu", bundle: .module,
               comment: "Menu: first row while clicking the icon turns Overbright on or off")
    }
    static var turnOn: String {
        String(localized: "Turn On Overbright", table: "StatusMenu", bundle: .module, comment: "Menu: turns Overbright on")
    }
    static var turnOff: String {
        String(localized: "Turn Off Overbright", table: "StatusMenu", bundle: .module, comment: "Menu: turns Overbright off")
    }
    static var dimAll: String {
        String(localized: "Dim All Displays", table: "StatusMenu", bundle: .module,
               comment: "Menu: dims every display to the last dim level")
    }
    static var stopDimming: String {
        String(localized: "Stop Dimming", table: "StatusMenu", bundle: .module,
               comment: "Menu: returns every dimmed display to its level")
    }
    static var allDisplays: String {
        String(localized: "All Displays", table: "StatusMenu", bundle: .module,
               comment: "Menu: submenu of quick levels while every display uses the same level")
    }
    static var pauseForAnHour: String {
        String(localized: "Pause for 1 Hour", table: "StatusMenu", bundle: .module,
               comment: "Menu: pauses extra brightness for one hour")
    }
    /// "Paused Until 14:20".
    static func pausedUntil(_ time: String) -> String {
        String(localized: "Paused Until \(time)", table: "StatusMenu", bundle: .module,
               comment: "Menu: disabled row while paused; the placeholder is a time of day")
    }
    static var resume: String {
        String(localized: "Resume", table: "StatusMenu", bundle: .module, comment: "Menu: ends a pause")
    }
    static var fillLight: String {
        String(localized: "Fill Light", table: "StatusMenu", bundle: .module, comment: "Menu: turns Fill Light on or off")
    }
    /// "Update Available: Overbright 0.2.0…".
    static func updateAvailable(_ version: String) -> String {
        String(localized: "Update Available: Overbright \(version)…", table: "StatusMenu", bundle: .module,
               comment: "Menu: opens the download page of a newer version; the placeholder is the version")
    }
    static var settings: String {
        String(localized: "Settings…", table: "StatusMenu", bundle: .module, comment: "Menu: opens the Settings window")
    }
    static var help: String {
        String(localized: "Help", table: "StatusMenu", bundle: .module, comment: "Menu: opens the Help window")
    }
    static var quit: String {
        String(localized: "Quit Overbright", table: "StatusMenu", bundle: .module, comment: "Menu: quits Overbright")
    }
    static var backToStandard: String {
        String(localized: "Back to Standard", table: "StatusMenu", bundle: .module,
               comment: "Menu: Dock menu row that turns Overbright off at once, keeping the levels")
    }

    // MARK: Banner actions (title case in the menu, DESIGN.md §12.3)

    /// The title of a banner's action as the menu's second line.
    static func title(of action: BannerActionTitle) -> String {
        switch action {
        case .resume: resume
        case .useCompatibilityMode:
            String(localized: "Use Compatibility Mode", table: "StatusMenu", bundle: .module,
                   comment: "Menu: banner action that switches to Compatibility mode next to another brightness app")
        case .continueAnyway:
            String(localized: "Continue Anyway", table: "StatusMenu", bundle: .module,
                   comment: "Menu: banner action that continues next to an app that changes display colors")
        case .openSystemSettings:
            String(localized: "Open System Settings", table: "StatusMenu", bundle: .module,
                   comment: "Menu: banner action that opens the System Settings pane the banner names")
        case .tryAgain:
            String(localized: "Try Again", table: "StatusMenu", bundle: .module, comment: "Menu: banner action that clears a stop")
        case .changePowerRules:
            String(localized: "Change Power Rules…", table: "StatusMenu", bundle: .module,
                   comment: "Menu: banner action that opens the power rules in Settings")
        case .changeHours:
            String(localized: "Change Hours…", table: "StatusMenu", bundle: .module,
                   comment: "Menu: banner action that opens the schedule in Settings")
        }
    }

    /// The kinds of banner action titles.
    enum BannerActionTitle { case resume, useCompatibilityMode, continueAnyway, openSystemSettings, tryAgain,
                                  changePowerRules, changeHours }
}
