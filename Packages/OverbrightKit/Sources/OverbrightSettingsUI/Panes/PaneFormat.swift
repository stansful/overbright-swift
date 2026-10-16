// OverbrightSettingsUI/Panes/PaneFormat.swift — the choices of the panes' pop-ups with their labels, in the user's
// locale through `Measurement` / `FormatStyle` (DESIGN.md §12.5, §16): "5 minutes", "1 hour", "1.5 hours", "20%".
// The allowed values are ARCHITECTURE.md §3.8's (`automations.autoOffMinutes`, `automations.batteryThreshold`,
// `automations.oledIdleMinutes`). Pure (tested).
import Foundation
import OverbrightDesign

/// Pop-up choices and their labels.
enum PaneFormat {
    /// Automations ▸ Turn off after: never, or these minutes (5, 10, 15, 20, 30, 45 minutes, 1, 1.5 and 2 hours).
    static let autoOffMinutes: [Int?] = [nil, 5, 10, 15, 20, 30, 45, 60, 90, 120]
    /// Automations ▸ Battery level: 5 … 95 % in steps of 5.
    static let batteryThresholds = Array(stride(from: 5, through: 95, by: 5))
    /// Automations ▸ OLED displays: minutes without input before extra brightness pauses.
    static let oledIdleMinutes = [1, 2, 5, 10, 15, 30]

    /// "5 minutes", "1 hour", "1.5 hours": a whole-minute duration spelled out, in hours from one hour on.
    static func duration(minutes: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let style = Measurement<UnitDuration>.FormatStyle(width: .wide, locale: locale, usage: .asProvided,
                                                          numberFormatStyle: .number.precision(.fractionLength(0...1)))
        guard minutes >= 60 else {
            return Measurement(value: Double(minutes), unit: UnitDuration.minutes).formatted(style)
        }
        return Measurement(value: Double(minutes) / 60, unit: UnitDuration.hours).formatted(style)
    }

    /// "Never" or the duration (Turn off after).
    static func autoOff(_ minutes: Int?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let minutes else {
            return String(localized: "Never", bundle: .module,
                          comment: "Settings ▸ Automations: Turn off after, pop-up item (the default: no timer)")
        }
        return duration(minutes: minutes, locale: locale)
    }

    /// "20%" / "20 %" (Battery level).
    static func percent(_ percent: Int, locale: Locale = .autoupdatingCurrent) -> String {
        (Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The Fill Light warmth (0 = cool … 1 = warm) in kelvin: 6,500 K … 3,000 K (ARCHITECTURE.md §3.8).
    static func kelvin(warmth: Double) -> Double {
        coolKelvin - (coolKelvin - warmKelvin) * min(max(warmth, 0), 1)
    }

    /// The cool end of the warmth slider.
    static let coolKelvin = 6500.0
    /// The warm end of the warmth slider.
    static let warmKelvin = 3000.0
}
