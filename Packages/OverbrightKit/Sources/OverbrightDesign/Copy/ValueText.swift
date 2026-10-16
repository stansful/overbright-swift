// OverbrightDesign/Copy/ValueText.swift — a level in canonical units. DESIGN.md §1 principle 4, §5.5, §5.6, §12.5,
// §12.7. Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:)` are fixed; WP9 writes the formats.
// The value text of a level is byte-identical in the readout, the HUD, the menu, Get State and the value tag; VoiceOver
// hears the same words with "times" and "percent" spelled out.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The readout, value-tag and VoiceOver text of a level ("Bright room · ≈ ×1.29" / "Bright room, about 1.29 times,
/// not calibrated").
public nonisolated struct ValueText: Hashable, Sendable {
    /// The visible text.
    public var text: String
    /// The VoiceOver value.
    public var accessibilityText: String

    /// A value text.
    public init(text: String, accessibilityText: String) { self.text = text; self.accessibilityText = accessibilityText }

    /// The canonical text of `values` (multipliers through `FormatStyle`, nits rounded to 5 and prefixed "≈").
    public static func make(_ values: ReadoutValues) -> ValueText { make(values, in: .app) }

    /// `make(_:)` in `language`.
    public static func make(_ values: ReadoutValues, in language: CopyLanguage) -> ValueText {
        switch values.state {
        case .off: return same(CommonNames.off(in: language))
        case .standard: return same(LevelPreset.standard.localizedName(in: language))
        case .preparing: return same(CommonNames.preparing(in: language))
        case .dim: return dimmed(percent: values.dimPercent ?? 100, in: language)
        case .boost: return boost(values, in: language)
        }
    }

    /// The value of a slider position on a display whose boost half tops out at `top` and shows `presets`: "Standard",
    /// "Dimmed · 25%", "Bright room · ×1.29" at a shown preset, "×1.42" between presets ("≈" while `isEstimate`).
    /// The value tag and VoiceOver of `BoostSlider` (DESIGN.md §5.5).
    public static func forLevel(_ level: LevelPosition, top: Double, presets: [LevelPreset],
                                            isEstimate: Bool, in language: CopyLanguage = .app) -> ValueText {
        if level.isDim {
            let percent = Int((LevelMapping.dimLight(for: level) * 100).rounded())
            return dimmed(percent: min(max(percent, 2), 99), in: language)
        }
        guard level.isBoost, top > 1 else { return same(LevelPreset.standard.localizedName(in: language)) }
        let gain = LevelMapping.requestedGain(for: level, top: top)
        let preset = LevelMapping.preset(at: level).flatMap { presets.contains($0) ? $0 : nil }
        return boost(gain: gain, preset: preset, nits: nil, requested: nil, isEstimate: isEstimate, in: language)
    }

    /// "Dimmed · 25%" / "Dimmed, 25%": dimming as a percentage of Standard light.
    public static func dimmed(percent: Int, in language: CopyLanguage = .app) -> ValueText {
        let value = CopyFormat.percent(percent, in: language)
        let state = CommonNames.dimmed(in: language)
        return ValueText(text: CopyFormat.parts(state, value, in: language),
                         accessibilityText: CopyFormat.spokenParts(state, value, in: language))
    }

    /// The allowed-now marker's help tag and VoiceOver content: "macOS allows ×1.55 now. This display can reach ×2.6
    /// at most." (`peak`: the Peak ceiling at full brightness; the second sentence is left out without one).
    public static func extraRange(allowed: Double, peak: Double?, in language: CopyLanguage = .app)
        -> ValueText {
        var text = allowsNow(CopyFormat.multiplier(allowed, in: language), in: language)
        var said = allowsNow(CopyFormat.spokenMultiplier(allowed, in: language), in: language)
        if let peak {
            text = CopyFormat.sentences(text, canReach(CopyFormat.roughMultiplier(peak, in: language), in: language),
                                        in: language)
            said = CopyFormat.sentences(said, canReach(CopyFormat.spokenRoughMultiplier(peak, in: language), in: language),
                                        in: language)
        }
        return ValueText(text: text, accessibilityText: said)
    }

    /// The readout's help tag: the full-brightness hint, and "Not calibrated: this is an estimate." while `isEstimate`.
    public static func readoutHelp(isEstimate: Bool, in language: CopyLanguage = .app) -> String {
        let hint = String(localized: "For the most light, turn your display brightness all the way up first; Overbright adds to it.",
                          bundle: language.bundle, locale: language.locale,
                          comment: "Panel ▸ Display card: help tag of the readout")
        guard isEstimate else { return hint }
        let estimate = String(localized: "Not calibrated: this is an estimate.", bundle: language.bundle,
                              locale: language.locale, comment: "Panel ▸ Display card: help tag of an uncalibrated readout")
        return CopyFormat.sentences(hint, estimate, in: language)
    }

    /// "small gain on this display": the value tag's suffix when Max is below ×1.3 (DESIGN.md §5.5).
    public static func smallGain(in language: CopyLanguage = .app) -> String {
        String(localized: "small gain on this display", bundle: language.bundle, locale: language.locale,
               comment: "Panel: value tag suffix when the display’s Max is below ×1.3, as in “Max · ×1.20 · small gain on this display”")
    }

    /// The value tag while a guard pauses the display (DESIGN.md §5.5 "Paused"): moving the slider stores the level
    /// but does not lift battery, Low Power Mode, heat, the schedule or a Focus, so the tag names the guard ("Paused:
    /// Low Power Mode"). Nil for every other reason: a pause the user set ends when the slider moves, a warm Mac only
    /// caps the level (the tag keeps its value), and per-display reasons have their chip.
    public static func guarded(by reason: LimitReason, in language: CopyLanguage = .app) -> ValueText? {
        switch reason {
        case .battery, .onBattery, .lowPowerMode, .thermalCritical, .outsideSchedule, .focusOff:
            return HUDText.reasonLine(for: reason, in: language).map(same)
        default:
            return nil
        }
    }

    // MARK: Private

    private static func allowsNow(_ multiplier: String, in language: CopyLanguage) -> String {
        String(localized: "macOS allows \(multiplier) now.", bundle: language.bundle, locale: language.locale,
               comment: "Panel: the slider’s allowed-now marker (help tag ×1.55, VoiceOver “1.55 times”); the argument is that multiplier")
    }

    private static func canReach(_ multiplier: String, in language: CopyLanguage) -> String {
        String(localized: "This display can reach \(multiplier) at most.", bundle: language.bundle, locale: language.locale,
               comment: "Panel: the allowed-now marker, after “macOS allows …”; the argument is the Peak ceiling (×2.6, or “2.6 times”)")
    }

    private static func asked(_ multiplier: String, in language: CopyLanguage) -> String {
        String(localized: "asked \(multiplier)", bundle: language.bundle, locale: language.locale,
               comment: "Panel: the level asked for when macOS allows less, as in “×1.21 · asked ×1.47” (VoiceOver: “asked 1.47 times”)")
    }

    private static func same(_ text: String) -> ValueText { ValueText(text: text, accessibilityText: text) }

    private static func boost(_ values: ReadoutValues, in language: CopyLanguage) -> ValueText {
        let limited = values.requestedGain.flatMap { $0 > values.appliedGain + 0.005 ? $0 : nil }
        return boost(gain: values.appliedGain, preset: limited == nil ? values.preset : nil, nits: values.nits,
                     requested: limited, isEstimate: values.isEstimate, in: language)
    }

    private static func boost(gain: Double, preset: LevelPreset?, nits: Double?, requested: Double?,
                                          isEstimate: Bool, in language: CopyLanguage) -> ValueText {
        var text = CopyFormat.multiplier(gain, isEstimate: isEstimate, in: language)
        var said = CopyFormat.spokenMultiplier(gain, isEstimate: isEstimate, in: language)
        if let preset, preset != .standard {
            let name = preset.localizedName(in: language)
            text = CopyFormat.parts(name, text, in: language)
            said = CopyFormat.spokenParts(name, said, in: language)
        }
        if let nits {
            text = CopyFormat.parts(text, CopyFormat.nits(nits, in: language), in: language)
            said = CopyFormat.spokenParts(said, CopyFormat.spokenNits(nits, in: language), in: language)
        }
        if let requested {
            text = CopyFormat.parts(text, asked(CopyFormat.multiplier(requested, in: language), in: language),
                                    in: language)
            said = CopyFormat.spokenParts(said, asked(CopyFormat.spokenMultiplier(requested, in: language), in: language),
                                          in: language)
        }
        if isEstimate {
            let note = String(localized: "not calibrated", bundle: language.bundle, locale: language.locale,
                              comment: "VoiceOver: ends an estimated value, as in “Bright room, about 1.29 times, not calibrated”")
            said = CopyFormat.spokenParts(said, note, in: language)
        }
        return ValueText(text: text, accessibilityText: said)
    }
}
