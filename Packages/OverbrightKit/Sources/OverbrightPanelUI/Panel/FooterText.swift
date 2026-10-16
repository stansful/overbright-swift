// OverbrightPanelUI/Panel/FooterText.swift — the words of the footer guard chips and their menus. DESIGN.md §5.9
// (chip labels sentence case; menu rows title case, AppKit chrome), §12.5 (percentages and durations through
// FormatStyle), §12.7 (VoiceOver labels).
import Foundation

/// Copy of the footer chips (PanelUI's catalog).
enum FooterText {
    // MARK: Chip labels

    /// "Below 20 %": pause below a battery level.
    static func below(_ percent: String) -> String {
        String(localized: "Below \(percent)", bundle: .module,
               comment: "Panel ▸ Footer chip: battery rule, pause below this level; the placeholder is a percentage")
    }
    static var adapterOnly: String {
        String(localized: "Adapter only", bundle: .module, comment: "Panel ▸ Footer chip: battery rule, pause on battery")
    }
    static var anyCharge: String {
        String(localized: "Any charge", bundle: .module, comment: "Panel ▸ Footer chip: battery rule, keep boosting")
    }
    static var autoPause: String {
        String(localized: "Auto-pause", bundle: .module, comment: "Panel ▸ Footer chip: some pause rule is on")
    }
    static var autoPauseOff: String {
        String(localized: "Auto-pause · Off", bundle: .module, comment: "Panel ▸ Footer chip: every pause rule is off")
    }
    static var noTimer: String {
        String(localized: "No timer", bundle: .module, comment: "Panel ▸ Footer chip: the auto-off timer is not set")
    }
    /// "Off in 23 min" (counting down).
    static func offIn(_ duration: String) -> String {
        String(localized: "Off in \(duration)", bundle: .module,
               comment: "Panel ▸ Footer chip: the timer runs; the placeholder is the time left, e.g. “23 min”")
    }
    /// "Off after 30 min" (set, not running).
    static func offAfter(_ duration: String) -> String {
        String(localized: "Off after \(duration)", bundle: .module,
               comment: "Panel ▸ Footer chip: the timer is set but Overbright is off; the placeholder is its duration")
    }

    // MARK: VoiceOver

    static var batteryLimit: String {
        String(localized: "Battery limit", bundle: .module, comment: "VoiceOver: the Battery footer chip’s name")
    }
    static var timerLabel: String {
        String(localized: "Timer", bundle: .module, comment: "VoiceOver: the Timer footer chip’s name")
    }
    static var on: String { String(localized: "On", bundle: .module, comment: "VoiceOver: a footer chip’s rule is on") }
    static var off: String { String(localized: "Off", bundle: .module, comment: "Panel ▸ Footer chip: a rule is off") }
    /// "Battery limit, Below 20 %".
    static func labeled(_ name: String, _ value: String) -> String {
        String(localized: "\(name), \(value)", bundle: .module,
               comment: "VoiceOver: a footer chip’s name, then its state")
    }

    // MARK: Menus (title case)

    static var pauseBelowALevel: String {
        String(localized: "Pause Below a Level", bundle: .module, comment: "Menu: Battery footer chip, the default rule")
    }
    static var pauseOnBattery: String {
        String(localized: "Pause on Battery", bundle: .module, comment: "Menu: Battery footer chip, pause whenever on battery")
    }
    static var keepBoosting: String {
        String(localized: "Keep Boosting", bundle: .module, comment: "Menu: Battery footer chip, no battery rule")
    }
    static var batteryLevel: String {
        String(localized: "Battery Level", bundle: .module, comment: "Menu: Battery footer chip, submenu of levels")
    }
    static var pauseForFullScreenVideo: String {
        String(localized: "Pause for Full-Screen Video", bundle: .module, comment: "Menu: Auto-pause footer chip rule")
    }
    static var pauseForEveryFullScreenApp: String {
        String(localized: "Pause for Every Full-Screen App", bundle: .module, comment: "Menu: Auto-pause footer chip rule")
    }
    static var pauseForListedApps: String {
        String(localized: "Pause for Apps in the List", bundle: .module,
               comment: "Menu: Auto-pause footer chip, the switch of the paused-apps list")
    }
    static var editApps: String {
        String(localized: "Edit Apps…", bundle: .module, comment: "Menu: Auto-pause footer chip, opens the paused-apps list")
    }
    static var turnOffAfter: String {
        String(localized: "Turn Off After", bundle: .module, comment: "Menu: Timer footer chip, submenu of durations")
    }
    static var never: String {
        String(localized: "Never", bundle: .module, comment: "Menu: Timer footer chip, no auto-off")
    }

    // MARK: Numbers

    /// A battery percentage through FormatStyle ("20%" in English, "20 %" in French).
    static func percent(_ value: Int) -> String { (Double(value) / 100).formatted(.percent) }

    /// A short duration ("23 min", "1 hr, 30 min").
    static func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// A menu duration in title case where the language capitalizes menus ("15 Minutes", "1 Hour").
    static func menuDuration(minutes: Int) -> String {
        let text = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
        let locale = Locale.current
        return locale.language.languageCode == .english ? text.capitalized(with: locale) : text
    }
}
