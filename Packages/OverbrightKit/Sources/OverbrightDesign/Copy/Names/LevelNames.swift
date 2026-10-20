// OverbrightDesign/Copy/Names/LevelNames.swift — the user-facing names of levels and ceilings. DESIGN.md §5.5, §7.4,
// §12.5, §16 (vocabulary: Standard, Indoor · Bright room · Sunlight · Max, Safe · Peak, "Max" never for a ceiling).
// Panel and readouts use sentence case.
import Foundation
import OverbrightCore

public extension LevelPreset {
    /// "Bright room": the name in the readout, the value tag, the HUD and VoiceOver (sentence case).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .standard: String(localized: "Standard", bundle: b, locale: l,
                               comment: "Panel: the level macOS itself shows (the slider's detent), in readouts, the HUD and VoiceOver")
        case .indoor: String(localized: "Indoor", bundle: b, locale: l,
                             comment: "Panel: the lowest extra-brightness preset, in readouts, the HUD and VoiceOver")
        case .brightRoom: String(localized: "Bright room", bundle: b, locale: l,
                                 comment: "Panel: the second extra-brightness preset (the default), sentence case")
        case .sunlight: String(localized: "Sunlight", bundle: b, locale: l,
                               comment: "Panel: the third extra-brightness preset")
        case .max: String(localized: "Max", bundle: b, locale: l,
                          comment: "Panel: the top extra-brightness preset (never a name for a ceiling)")
        }
    }
}

public extension CapMode {
    /// "Safe" / "Peak": the ceilings (Settings ▸ Displays ▸ Limit segments, chips, verdicts).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .safe: String(localized: "Safe", bundle: language.bundle, locale: language.locale,
                           comment: "Settings ▸ Displays: the default ceiling, the level a display holds across the whole screen (segment)")
        case .peak: String(localized: "Peak", bundle: language.bundle, locale: language.locale,
                           comment: "Settings ▸ Displays: the higher ceiling, up to what macOS allows (segment)")
        }
    }
}
