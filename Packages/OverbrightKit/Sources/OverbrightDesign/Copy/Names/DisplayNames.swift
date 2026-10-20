// OverbrightDesign/Copy/Names/DisplayNames.swift — the user-facing names of per-display choices.
// DESIGN.md §7.4 (Display type), §7.8 (Trigger method), §10 (self-test rows), §16 (vocabulary: never "fallback" or
// "overlay").
import Foundation
import OverbrightCore

public extension TriggerStrategy {
    /// "Tagged layer" … "HDR video still" (Settings ▸ Advanced ▸ Trigger method, the self-test).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .taggedLayer: String(localized: "Tagged layer", bundle: b, locale: l,
                                  comment: "Settings ▸ Advanced: a trigger method, an HDR-tagged layer (pop-up item, self-test row)")
        case .metalOneShot: String(localized: "Metal layer", bundle: b, locale: l,
                                   comment: "Settings ▸ Advanced: a trigger method, one Metal frame (pop-up item, self-test row)")
        case .metalKeepAlive: String(localized: "Metal layer, refreshed", bundle: b, locale: l,
                                     comment: "Settings ▸ Advanced: a trigger method, a Metal frame shown again every few seconds")
        case .hlgSampleBuffer: String(localized: "HDR frame", bundle: b, locale: l,
                                      comment: "Settings ▸ Advanced: a trigger method, one HDR video frame in memory")
        case .hlgStill: String(localized: "HDR video still", bundle: b, locale: l,
                               comment: "Settings ▸ Advanced: a trigger method, a paused HDR video still")
        }
    }

    /// "Tagged layer, black": the method and the pixel it showed (self-test progress and results).
    nonisolated func localizedName(pixel: TriggerPixel, in language: CopyLanguage = .app) -> String {
        CopyFormat.spokenParts(localizedName(in: language), pixel.localizedName(in: language), in: language)
    }
}

public extension TriggerPixel {
    /// "black" / "white" / "bright": the trigger's pixel in a method name.
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .black: String(localized: "black", bundle: b, locale: l,
                            comment: "Self-test: the trigger shows a black pixel, as in “Tagged layer, black” (lowercase)")
        case .sdrWhite: String(localized: "white", bundle: b, locale: l,
                               comment: "Self-test: the trigger shows a white pixel, as in “Metal layer, white” (lowercase)")
        case .bright: String(localized: "bright", bundle: b, locale: l,
                             comment: "Self-test: the trigger shows a pixel brighter than white, as in “Metal layer, bright” (lowercase)")
        }
    }
}

public extension OLEDOverride {
    /// "Automatic (OLED)" / "Automatic (not OLED)" · "OLED" · "Not OLED" (Settings ▸ Displays ▸ Display type);
    /// `detectedOLED` is what Automatic found.
    nonisolated func localizedName(detectedOLED: Bool, in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .automatic where detectedOLED:
            String(localized: "Automatic (OLED)", bundle: b, locale: l,
                   comment: "Settings ▸ Displays: Display type pop-up item when the display was detected as OLED")
        case .automatic:
            String(localized: "Automatic (not OLED)", bundle: b, locale: l,
                   comment: "Settings ▸ Displays: Display type pop-up item when the display was detected as not OLED")
        case .oled: String(localized: "OLED", bundle: b, locale: l,
                           comment: "Settings ▸ Displays: Display type pop-up item")
        case .notOLED: String(localized: "Not OLED", bundle: b, locale: l,
                              comment: "Settings ▸ Displays: Display type pop-up item")
        }
    }
}
