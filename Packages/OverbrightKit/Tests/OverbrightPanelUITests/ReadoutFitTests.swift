// OverbrightPanelUITests/ReadoutFitTests.swift — readouts fit one line of ≤ 200 pt and value tags the 240-pt track
// (DESIGN.md §5.5, §5.6, §16; ARCHITECTURE.md §8.8 width rules `readout` and `valueTag`), measured in the readout and
// value-tag type (rounded, monospaced digits), in English and the pseudo-long locale. The texts are DESIGN.md §5.6's
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

    @Test func theCardKeepsItsReadoutInsideTheBudgetWhateverTheText() {
        let text = PseudoLocale.lengthen(PseudoLocale.lengthen("Bright room · ×1.29 · ≈ 775 nits"))
        let width = FitMeasure.width(Text(verbatim: text).font(Self.readoutFont).lineLimit(1),
                                     offered: PanelLayout.readoutWidth)
        #expect(width <= PanelLayout.readoutWidth)
    }
}
