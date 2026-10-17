// OverbrightPanelUI/Panel/OLEDNotice.swift — "Use extra brightness on this OLED display?", asked before extra
// brightness turns on for an OLED display from the card, the chip, the menu or Welcome. DESIGN.md §12.4 (title-case
// buttons), §5.4, §12.5 (durations through FormatStyle); D8. The idle pause it names is the configured one
// (Automations ▸ OLED displays, `AutomationSettings.oledIdleMinutes`, 1–30 minutes), worded as Settings' own notice
// words it, so every surface states the same time.
import AppKit
import Foundation
import OverbrightCore

/// The OLED notice alert.
public enum OLEDNotice {
    /// The alert's title.
    public static var title: String {
        String(localized: "Use extra brightness on this OLED display?", bundle: .module,
               comment: "Panel: title of the alert shown before extra brightness turns on for an OLED display")
    }

    /// The alert's text, naming the idle time after which extra brightness pauses ("5 minutes", "1 hour").
    public static func message(idleMinutes: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let idle = idleDuration(minutes: idleMinutes, locale: locale)
        return String(localized: "Bright content that stays in one place for a long time, like the menu bar, can wear OLED panels unevenly. Overbright keeps extra brightness lower on OLED displays and pauses it after \(idle) without input.",
                      bundle: .module,
                      comment: "Panel: text of the OLED notice alert; the argument is a duration such as 5 minutes")
    }

    /// "5 minutes", "1 hour", "1.5 hours": the idle time spelled out, in hours from one hour on (as Settings says it).
    public static func idleDuration(minutes: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let style = Measurement<UnitDuration>.FormatStyle(width: .wide, locale: locale, usage: .asProvided,
                                                          numberFormatStyle: .number.precision(.fractionLength(0...1)))
        guard minutes >= 60 else {
            return Measurement(value: Double(minutes), unit: UnitDuration.minutes).formatted(style)
        }
        return Measurement(value: Double(minutes) / 60, unit: UnitDuration.hours).formatted(style)
    }

    /// The confirming button.
    public static var turnOn: String {
        String(localized: "Turn On", bundle: .module, comment: "Panel: OLED notice button that turns extra brightness on")
    }

    /// The cancelling button.
    public static var cancel: String {
        String(localized: "Cancel", bundle: .module, comment: "Panel: OLED notice button that keeps extra brightness off")
    }

    /// Shows the alert (app-modal) and returns whether the user chose Turn On. `displayName` is unused in the copy
    /// (the question names "this OLED display") but kept for VoiceOver context in the alert's accessibility label;
    /// `idleMinutes` is the configured OLED idle pause.
    public static func confirm(_ displayName: String, idleMinutes: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message(idleMinutes: idleMinutes)
        alert.alertStyle = .informational
        alert.addButton(withTitle: turnOn)
        alert.addButton(withTitle: cancel)
        alert.window.setAccessibilityLabel(displayName)
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// The question for `settings`' configured idle pause (the default of `PanelCommands` and Welcome).
    public static func confirmer(_ settings: SettingsStore) -> @MainActor (String) -> Bool {
        { name in confirm(name, idleMinutes: settings[AutomationSettings.oledIdleMinutes]) }
    }
}
