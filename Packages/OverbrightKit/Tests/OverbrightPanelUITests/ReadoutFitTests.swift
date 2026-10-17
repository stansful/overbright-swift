// OverbrightPanelUITests/ReadoutFitTests.swift — readouts fit one line of ≤ 200 pt and value tags the 240-pt track
// (DESIGN.md §5.5, §5.6, §16; ARCHITECTURE.md §8.8 width rules `readout` and `valueTag`), measured in the readout and
// value-tag type (rounded, monospaced digits), in English, the pseudo-long locale and every language Overbright ships
// (WP15). The texts are DESIGN.md §5.6's
// and §5.5's, plus what Design's `ValueText` makes for the gallery's readouts once WP9's copy lands. The value tag's
// "small gain" suffix may wrap (§16), so it is measured without the suffix.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct ReadoutFitTests {
    /// DESIGN.md §2.2 `readout` and `valueTag`.
    static let readoutFont = Font.system(size: 13, weight: .medium, design: .rounded).monospacedDigit()
    static let valueTagFont = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()

    /// DESIGN.md §5.6's readouts.
    static let englishReadouts = [
        "Off", "Standard", "Bright room · ×1.29 · ≈ 775 nits", "Bright room · ×1.29", "Bright room · ≈ ×1.29",
        "×1.42 · ≈ 852 nits", "≈ ×1.42", "×1.21 · asked ×1.47", "Dimmed · 25 %", "Preparing…", "Sunlight · ≈ ×2.04",
    ]

    /// DESIGN.md §5.5's value tags (the guard's words included).
    static let englishValueTags = [
        "Bright room · ×1.29", "Standard", "×1.42", "Dimmed · 25 %", "≈ ×1.29", "Max · ≈ ×1.30",
        "Paused: Low Power Mode", "Paused: battery below 20 %",
    ]

    /// Every readout the gallery's cards show, in Design's words (empty until WP9's copy lands).
    static var builderReadouts: [String] {
        ScriptedStatuses.names.compactMap(ScriptedStatuses.services(named:)).flatMap { services in
            services.boost.status.displays.map { display in
                ValueText.make(DisplayCardModel(status: display, isMasterOn: services.boost.status.isOn,
                                                services: services).readout).text
            }
        }
        .filter { !$0.isEmpty }
    }

    @Test func readoutsFitOneLineInEnglish() {
        let failures = (Self.englishReadouts + Self.builderReadouts).compactMap { text -> String? in
            let width = FitMeasure.textWidth(text, Self.readoutFont)
            return width <= PanelLayout.readoutWidth ? nil : "«\(text)» \(width) pt"
        }
        #expect(failures.isEmpty, "readouts wider than \(PanelLayout.readoutWidth) pt: \(failures)")
    }

    /// The preset names a readout may start with (the card drops the name when the readout does not fit).
    static let presetNames = ["Indoor", "Bright room", "Sunlight", "Max"]

    /// `text` without its leading preset name, as the card's fallback draws it.
    static func withoutPreset(_ text: String) -> String {
        guard let name = presetNames.first(where: { text.hasPrefix($0 + " · ") }) else { return text }
        return String(text.dropFirst(name.count + 3))
    }

    @Test func readoutsFitOneLineInThePseudoLongLocale() {
        let failures = (Self.englishReadouts + Self.builderReadouts).compactMap { text -> String? in
            let full = FitMeasure.textWidth(PseudoLocale.lengthen(text), Self.readoutFont)
            let numbers = FitMeasure.textWidth(PseudoLocale.lengthen(Self.withoutPreset(text)), Self.readoutFont)
            return full <= PanelLayout.readoutWidth || numbers <= PanelLayout.readoutWidth ? nil
                : "«\(text)» \(full) pt, without the preset \(numbers) pt"
        }
        #expect(failures.isEmpty, "pseudo-long readouts wider than \(PanelLayout.readoutWidth) pt: \(failures)")
    }

    @Test func theFallbackDropsOnlyThePresetName() {
        #expect(Self.withoutPreset("Bright room · ×1.29 · ≈ 775 nits") == "×1.29 · ≈ 775 nits")
        #expect(Self.withoutPreset("×1.42") == "×1.42")
        let values = ReadoutValues(state: .boost, appliedGain: 1.29, requestedGain: nil, nits: 775, preset: .brightRoom,
                                   isEstimate: false, dimPercent: nil)
        let fallback = DisplayCardView.withoutPreset(values)
        #expect(fallback.preset == nil && fallback.appliedGain == 1.29 && fallback.nits == 775)
    }

    @Test func valueTagsFitTheTrack() {
        for text in Self.englishValueTags {
            #expect(FitMeasure.textWidth(text, Self.valueTagFont) <= PanelLayout.trackWidth, "«\(text)»")
            let longer = PseudoLocale.lengthen(text)
            #expect(FitMeasure.textWidth(longer, Self.valueTagFont) <= PanelLayout.trackWidth, "«\(longer)»")
        }
    }

    // MARK: Every language (WP15)

    private static func values(_ state: ReadoutValues.State, _ gain: Double = 1, requested: Double? = nil,
                               nits: Double? = nil, preset: LevelPreset? = nil, estimate: Bool = false,
                               dim: Int? = nil) -> ReadoutValues {
        ReadoutValues(state: state, appliedGain: gain, requestedGain: requested, nits: nits, preset: preset,
                      isEstimate: estimate, dimPercent: dim)
    }

    /// DESIGN.md §5.6's readouts as numbers (`englishReadouts`), plus every preset with four-digit nits.
    static let readoutValues: [ReadoutValues] = [
        values(.off), values(.standard), values(.boost, 1.29, nits: 775, preset: .brightRoom),
        values(.boost, 1.29, preset: .brightRoom), values(.boost, 1.29, preset: .brightRoom, estimate: true),
        values(.boost, 1.42, nits: 852), values(.boost, 1.42, estimate: true), values(.boost, 1.21, requested: 1.47),
        values(.dim, 0.25, dim: 25), values(.preparing), values(.boost, 2.04, preset: .sunlight, estimate: true),
        values(.boost, 1.12, nits: 1_010, preset: .indoor, estimate: true),
        values(.boost, 1.29, nits: 1_165, preset: .brightRoom, estimate: true),
        values(.boost, 2.04, nits: 1_835, preset: .sunlight, estimate: true),
        values(.boost, 2.6, nits: 2_340, preset: .max, estimate: true),
    ]

    /// DESIGN.md §5.5's value tags as numbers (`englishValueTags`), every preset, and each guard's words.
    static func valueTags(in language: CopyLanguage) -> [String] {
        let levels = [values(.boost, 1.29, preset: .brightRoom), values(.standard), values(.boost, 1.42),
                      values(.dim, 0.25, dim: 25), values(.boost, 1.29, estimate: true),
                      values(.boost, 1.29, preset: .brightRoom, estimate: true),
                      values(.boost, 1.12, preset: .indoor, estimate: true),
                      values(.boost, 2.04, preset: .sunlight, estimate: true),
                      values(.boost, 1.3, preset: .max, estimate: true)]
        let guards: [LimitReason] = [.battery(percent: 12, threshold: 20), .onBattery, .lowPowerMode, .thermalCritical,
                                     .outsideSchedule, .focusOff]
        return levels.map { ValueText.make($0, in: language).text }
            + guards.compactMap { ValueText.guarded(by: $0, in: language)?.text }
    }

    /// Every readout fits its line, or drops the preset name and then fits (the card's fallback).
    @Test(arguments: ShippedLanguages.codes)
    func readoutsFitOneLineInEveryLanguage(_ code: String) throws {
        let language = try #require(ShippedLanguages.design(code), "\(code): no Design table")
        let builder = ScriptedStatuses.names.compactMap(ScriptedStatuses.services(named:)).flatMap { services in
            services.boost.status.displays.map { display in
                DisplayCardModel(status: display, isMasterOn: services.boost.status.isOn, services: services).readout
            }
        }
        let failures = (Self.readoutValues + builder).compactMap { values -> String? in
            let full = ValueText.make(values, in: language).text
            let numbers = ValueText.make(DisplayCardView.withoutPreset(values), in: language).text
            let (fullWidth, numbersWidth) = (FitMeasure.textWidth(full, Self.readoutFont),
                                             FitMeasure.textWidth(numbers, Self.readoutFont))
            return fullWidth <= PanelLayout.readoutWidth || numbersWidth <= PanelLayout.readoutWidth ? nil
                : "«\(full)» \(fullWidth) pt, without the preset \(numbersWidth) pt"
        }
        #expect(failures.isEmpty, "\(code): readouts wider than \(PanelLayout.readoutWidth) pt: \(failures)")
        let caption = try #require(PanelWords(code), "\(code): no PanelUI table").compatibilityMode
        #expect(FitMeasure.textWidth(caption, .caption) <= PanelLayout.readoutWidth, "\(code): «\(caption)»")
    }

    @Test(arguments: ShippedLanguages.codes)
    func valueTagsFitTheTrackInEveryLanguage(_ code: String) throws {
        let tags = Self.valueTags(in: try #require(ShippedLanguages.design(code), "\(code): no Design table"))
        #expect(tags.count == 15, "\(code)")
        let failures = tags.compactMap { text -> String? in
            let width = FitMeasure.textWidth(text, Self.valueTagFont)
            return width <= PanelLayout.trackWidth ? nil : "«\(text)» \(width) pt"
        }
        #expect(failures.isEmpty, "\(code): value tags wider than \(PanelLayout.trackWidth) pt: \(failures)")
    }

    @Test func theCardKeepsItsReadoutInsideTheBudgetWhateverTheText() {
        let text = PseudoLocale.lengthen(PseudoLocale.lengthen("Bright room · ×1.29 · ≈ 775 nits"))
        let width = FitMeasure.width(Text(verbatim: text).font(Self.readoutFont).lineLimit(1),
                                     offered: PanelLayout.readoutWidth)
        #expect(width <= PanelLayout.readoutWidth)
    }
}
