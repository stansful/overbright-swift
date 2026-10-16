// OverbrightDesign/Copy/PowerStateText.swift — the power source in words: Settings ▸ Automations ▸ Now ("Battery 64%,
// on battery" / "On power adapter"). DESIGN.md §7.5.
import Foundation
import OverbrightCore

/// The live power line of Settings ▸ Automations.
public nonisolated enum PowerStateText {
    /// "Battery 64%, on battery", "On battery", "On power adapter", "On a UPS" or "Power source unknown".
    public static func make(_ power: PowerState, in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        switch power.source {
        case .battery:
            guard let percent = power.batteryPercent else {
                return String(localized: "On battery", bundle: b, locale: l,
                              comment: "Settings ▸ Automations: Now, running on battery (charge unknown)")
            }
            let charge = CopyFormat.percent(percent, in: language)
            return String(localized: "Battery \(charge), on battery", bundle: b, locale: l,
                          comment: "Settings ▸ Automations: Now, running on battery; the argument is the charge such as 64%")
        case .adapter:
            return String(localized: "On power adapter", bundle: b, locale: l,
                          comment: "Settings ▸ Automations: Now, running on the power adapter")
        case .ups:
            return String(localized: "On a UPS", bundle: b, locale: l,
                          comment: "Settings ▸ Automations: Now, running on an uninterruptible power supply")
        case .unknown:
            return String(localized: "Power source unknown", bundle: b, locale: l,
                          comment: "Settings ▸ Automations: Now, when macOS does not report the power source")
        }
    }
}
