// OverbrightSettingsUI/Components/SettingsFormat.swift — values with their units, always through `FormatStyle` /
// `Measurement` (DESIGN.md §12.5, §16): "48 pt", "80 %", "5,100 K", "30 min", "1 hr, 30 min". Pure functions of the value
// and a locale (tested). Ported from Cranny's SettingsFormat (the owner's MIT code) with Overbright's units.
import Foundation

/// Formats setting values.
enum SettingsFormat {
    /// "48 pt" (Fill Light width).
    static func points(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return String(localized: "\(number) pt", bundle: .module,
                      comment: "Settings ▸ Fill Light: a width in typographic points, e.g. \"48 pt\"")
    }

    /// "80 %" (Fill Light brightness, battery level).
    static func percent(_ fraction: Double, locale: Locale = .autoupdatingCurrent) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// "5,100 K" / "5 100 K" (Fill Light warmth), in kelvin through `Measurement`.
    static func kelvin(_ kelvin: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: kelvin.rounded(), unit: UnitTemperature.kelvin)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0))).locale(locale))
    }

    /// "30 min", "1 hr, 30 min" (Turn off after, OLED idle).
    static func minutes(_ minutes: Int, locale: Locale = .autoupdatingCurrent) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }

    /// "Brighter, ⌃⌥⌘=": a name and its detail as one VoiceOver label, through a localized pattern rather than
    /// concatenation.
    static func pair(_ name: String, _ detail: String) -> String {
        String(localized: "\(name), \(detail)", bundle: .module,
               comment: "VoiceOver: a name and its detail read as one label in Settings (\"Brighter, Off\")")
    }
}
