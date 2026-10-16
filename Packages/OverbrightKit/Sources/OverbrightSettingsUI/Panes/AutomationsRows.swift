// OverbrightSettingsUI/Panes/AutomationsRows.swift — the rows of Settings ▸ Automations (DESIGN.md §7.5), shared by the
// pane and the search index. The ids of the first row of each group are the deep links the panel, the menu and the
// banners use (PanelUI's `SettingsLinks`): "automations#power", "#timer", "#apps", "#pausedApps", "#schedule".
import Foundation
import OverbrightCore

/// The rows of Settings ▸ Automations.
enum AutomationsRows {
    static var batteryGuard: SettingsRowInfo {
        SettingsRowInfo(.automations, "power",
                        title: String(localized: "On battery", bundle: .module,
                                      comment: "Settings ▸ Automations: what extra brightness does on battery (pop-up)"),
                        keywords: [PaneWords.battery,
                                   String(localized: "power", bundle: .module, comment: "Settings search: keyword for the power rows")])
    }

    static var batteryThreshold: SettingsRowInfo {
        SettingsRowInfo(.automations, "batteryThreshold",
                        title: String(localized: "Battery level", bundle: .module,
                                      comment: "Settings ▸ Automations: the battery level below which extra brightness pauses (pop-up)"),
                        keywords: [PaneWords.battery])
    }

    static var lowPowerMode: SettingsRowInfo {
        SettingsRowInfo(.automations, "lowPowerMode",
                        title: String(localized: "Pause in Low Power Mode", bundle: .module,
                                      comment: "Settings ▸ Automations: switch; “Low Power Mode” is macOS’s own name"),
                        keywords: [PaneWords.battery])
    }

    static var powerNow: SettingsRowInfo {
        SettingsRowInfo(.automations, "powerNow",
                        title: String(localized: "Now", bundle: .module,
                                      comment: "Settings ▸ Automations: label of the live power source line (“Battery 64%, on battery”)"),
                        keywords: [PaneWords.battery,
                                   String(localized: "power adapter", bundle: .module, comment: "Settings search: keyword for the live power line")])
    }

    static var heat: SettingsRowInfo {
        SettingsRowInfo(.automations, "heat",
                        title: String(localized: "Heat", bundle: .module,
                                      comment: "Settings ▸ Automations: label of the note about heat (Overbright limits extra brightness when the Mac is warm)"),
                        keywords: [String(localized: "thermal", bundle: .module, comment: "Settings search: keyword for the heat note"),
                                   String(localized: "warm", bundle: .module, comment: "Settings search: keyword for the heat note")])
    }

    static var timer: SettingsRowInfo {
        SettingsRowInfo(.automations, "timer",
                        title: String(localized: "Turn off after", bundle: .module,
                                      comment: "Settings ▸ Automations: the timer that turns Overbright off (pop-up)"),
                        keywords: [PaneWords.timer])
    }

    static var fullScreenVideo: SettingsRowInfo {
        SettingsRowInfo(.automations, "apps",
                        title: String(localized: "Pause for full-screen video (beta)", bundle: .module,
                                      comment: "Settings ▸ Automations: switch; extra brightness pauses while an app plays video full screen"),
                        keywords: [PaneWords.fullScreen,
                                   String(localized: "video", bundle: .module, comment: "Settings search: keyword for the video rules")])
    }

    static var everyFullScreenApp: SettingsRowInfo {
        SettingsRowInfo(.automations, "fullScreenApps",
                        title: String(localized: "Pause for every full-screen app", bundle: .module,
                                      comment: "Settings ▸ Automations: switch; extra brightness pauses while any app is full screen"),
                        keywords: [PaneWords.fullScreen])
    }

    static var games: SettingsRowInfo {
        SettingsRowInfo(.automations, "games",
                        title: String(localized: "Pause in games", bundle: .module, comment: "Settings ▸ Automations: switch"),
                        keywords: [String(localized: "game", bundle: .module, comment: "Settings search: keyword for Pause in games")])
    }

    static var pausedApps: SettingsRowInfo {
        SettingsRowInfo(.automations, "pausedApps",
                        title: String(localized: "Pause for these apps", bundle: .module,
                                      comment: "Settings ▸ Automations: switch above the list of apps that pause extra brightness"),
                        keywords: [String(localized: "apps", bundle: .module, comment: "Settings search: keyword for the list of apps that pause extra brightness")])
    }

    static var schedule: SettingsRowInfo {
        SettingsRowInfo(.automations, "schedule",
                        title: String(localized: "Only allow extra brightness at set times", bundle: .module,
                                      comment: "Settings ▸ Automations: switch of the schedule"),
                        keywords: [PaneWords.schedule,
                                   String(localized: "hours", bundle: .module, comment: "Settings search: keyword for the schedule")])
    }

    static var scheduleFrom: SettingsRowInfo {
        SettingsRowInfo(.automations, "scheduleFrom",
                        title: String(localized: "From", bundle: .module,
                                      comment: "Settings ▸ Automations: the time extra brightness is allowed from (time picker)"),
                        keywords: [PaneWords.schedule])
    }

    static var scheduleTo: SettingsRowInfo {
        SettingsRowInfo(.automations, "scheduleTo",
                        title: String(localized: "To", bundle: .module,
                                      comment: "Settings ▸ Automations: the time extra brightness is allowed until (time picker)"),
                        keywords: [PaneWords.schedule])
    }

    static var oledIdle: SettingsRowInfo {
        SettingsRowInfo(.automations, "oledIdle",
                        title: String(localized: "Pause extra brightness after no input for", bundle: .module,
                                      comment: "Settings ▸ Automations: OLED idle pause, followed by a duration pop-up"),
                        keywords: [PaneWords.oled,
                                   String(localized: "idle", bundle: .module, comment: "Settings search: keyword for the OLED idle pause")])
    }

    static var focus: SettingsRowInfo {
        SettingsRowInfo(.automations, "focus",
                        title: String(localized: "Choose what Overbright does in each Focus in Focus settings: leave it alone, turn it off, or turn it on at a level.",
                                      bundle: .module,
                                      comment: "Settings ▸ Automations: the Focus note; “Focus” is macOS’s own name"),
                        keywords: [PaneWords.focus])
    }
}
