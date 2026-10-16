// OverbrightDesignTests/ValueTextTests.swift — the readout rows of DESIGN.md §5.6 and the formats of §12.5, in English
// whatever the system language, and the locale's decimal separator (Russian «1,29»).
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightDesign

@Suite struct ValueTextTests {
    private func values(_ state: ReadoutValues.State, gain: Double = 1, requested: Double? = nil, nits: Double? = nil,
                        preset: LevelPreset? = nil, estimate: Bool = false, dim: Int? = nil) -> ReadoutValues {
        ReadoutValues(state: state, appliedGain: gain, requestedGain: requested, nits: nits, preset: preset,
                      isEstimate: estimate, dimPercent: dim)
    }

    private func text(_ v: ReadoutValues) -> String { ValueText.make(v, in: english).text }
    private func spoken(_ v: ReadoutValues) -> String { ValueText.make(v, in: english).accessibilityText }

    /// Every row of the readout table (DESIGN.md §5.6).
    @Test func theReadoutTable() {
        #expect(text(values(.off)) == "Off")
        #expect(text(values(.standard)) == "Standard")
        #expect(text(values(.boost, gain: 1.29, nits: 775, preset: .brightRoom)) == "Bright room · ×1.29 · ≈ 775 nits")
        #expect(text(values(.boost, gain: 1.29, preset: .brightRoom)) == "Bright room · ×1.29")
        #expect(text(values(.boost, gain: 1.29, preset: .brightRoom, estimate: true)) == "Bright room · ≈ ×1.29")
        #expect(text(values(.boost, gain: 1.42)) == "×1.42")
        #expect(text(values(.boost, gain: 1.42, nits: 852)) == "×1.42 · ≈ 850 nits")
        #expect(text(values(.boost, gain: 1.42, estimate: true)) == "≈ ×1.42")
        #expect(text(values(.boost, gain: 1.21, requested: 1.47)) == "×1.21 · asked ×1.47")
        #expect(text(values(.dim, gain: 0.25, dim: 25)) == "Dimmed · 25%")
        #expect(text(values(.preparing)) == "Preparing…")
    }

    @Test func voiceOverSpellsTheUnitsOut() {
        #expect(spoken(values(.boost, gain: 1.29, preset: .brightRoom)) == "Bright room, 1.29 times")
        #expect(spoken(values(.boost, gain: 1.29, preset: .brightRoom, estimate: true))
                == "Bright room, about 1.29 times, not calibrated")
        #expect(spoken(values(.boost, gain: 1.42)) == "1.42 times")
        #expect(spoken(values(.boost, gain: 1.29, nits: 775, preset: .brightRoom)) == "Bright room, 1.29 times, about 775 nits")
        #expect(spoken(values(.boost, gain: 1.21, requested: 1.47)) == "1.21 times, asked 1.47 times")
        #expect(spoken(values(.dim, dim: 25)) == "Dimmed, 25%")
        #expect(spoken(values(.standard)) == "Standard")
    }

    /// A limited level drops the preset name: the light on screen is not the preset's.
    @Test func aLimitedLevelShowsWhatWasAskedNotThePreset() {
        #expect(text(values(.boost, gain: 1.21, requested: 1.47, preset: .sunlight)) == "×1.21 · asked ×1.47")
        // A request that macOS meets is not "asked".
        #expect(text(values(.boost, gain: 1.47, requested: 1.47, preset: .sunlight)) == "Sunlight · ×1.47")
    }

    @Test func nitsRoundToFiveAndAreAlwaysAnEstimate() {
        #expect(CopyFormat.roundedNits(772.4) == 770)
        #expect(CopyFormat.roundedNits(773) == 775)
        #expect(CopyFormat.nits(1000, in: english) == "≈ 1,000 nits")
        #expect(CopyFormat.nits(1, in: english) == "≈ 0 nits")
    }

    /// The multiplier follows the locale's decimal separator (DESIGN.md §12.5: ×1,29 in Russian).
    @Test func theMultiplierUsesTheLocalesSeparator() {
        let russianFormats = CopyLanguage(bundle: english.bundle, locale: Locale(identifier: "ru"), timeZone: .gmt)
        #expect(CopyFormat.multiplier(1.29, in: english) == "×1.29")
        #expect(CopyFormat.multiplier(1.29, in: russianFormats) == "×1,29")
        #expect(CopyFormat.multiplier(1.4, in: english) == "×1.40")
        #expect(CopyFormat.roughMultiplier(2.587, in: english) == "×2.6")
    }

    /// The same level reads the same in the readout, the value tag and the HUD (DESIGN.md §1 principle 4).
    @Test func theValueTagMatchesTheReadoutAtAPreset() {
        let top = 1.667
        let tag = ValueText.forLevel(LevelPreset.sunlight.position, top: top, presets: [.indoor, .brightRoom, .sunlight, .max],
                                     isEstimate: true, in: english)
        let gain = LevelMapping.requestedGain(for: LevelPreset.sunlight.position, top: top)
        let readout = ValueText.make(values(.boost, gain: gain, preset: .sunlight, estimate: true), in: english)
        #expect(tag == readout)
        #expect(tag.text == "Sunlight · ≈ ×1.47")
    }

    /// A preset hidden on this display is not named: the value tag shows the bare multiplier.
    @Test func aHiddenPresetIsNotNamed() {
        let tag = ValueText.forLevel(LevelPreset.indoor.position, top: 1.3, presets: [.brightRoom, .max], isEstimate: false,
                                     in: english)
        #expect(tag.text == "×1.07")
    }

    @Test func theReadoutHelpTag() {
        #expect(ValueText.readoutHelp(isEstimate: false, in: english)
                == "For the most light, turn your display brightness all the way up first; Overbright adds to it.")
        #expect(ValueText.readoutHelp(isEstimate: true, in: english).hasSuffix(" Not calibrated: this is an estimate."))
    }

    @Test func timesAndDurationsComeFromFormatStyle() {
        let german = CopyLanguage(bundle: english.bundle, locale: Locale(identifier: "de_DE"), timeZone: .gmt)
        #expect(CopyFormat.time(minuteOfDay: 14 * 60 + 20, in: german) == "14:20")
        #expect(CopyFormat.time(minuteOfDay: 20 * 60, in: german) == "20:00")
        #expect(CopyFormat.time(minuteOfDay: 14 * 60 + 20, in: english) == "2:20\u{202F}PM")
        #expect(CopyFormat.duration(minutes: 23, in: english) == "23 min")
        #expect(CopyFormat.spokenDuration(minutes: 5, in: english) == "5 minutes")
        #expect(CopyFormat.percent(20, in: english) == "20%")
    }
}
