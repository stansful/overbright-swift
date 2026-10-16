// OverbrightPanelUITests/ChipFitTests.swift — status chips fit their own line: ≤ 280 pt, the card's inner width
// (DESIGN.md §5.7, §16; ARCHITECTURE.md §8.8 width rule `chip`), measured with the chip component itself, in English
// and the pseudo-long locale (+40 %). The English texts are DESIGN.md §12.2's; every chip Design's builder makes for a
// reason or phase is measured too (they become the catalog's words once WP9's copy lands). App names inside a chip are
// middle-truncated to fit, so the panel's layout keeps even a very long one inside the line.
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct ChipFitTests {
    /// DESIGN.md §12.2 and §12.1's badges (the chips of dim-only displays).
    static let englishChips = [
        "Preparing…", "No extra range", "Extra brightness off", "Limited by macOS", "Below full brightness", "Safe limit",
        "OLED limit", "Limited by heat", "Paused: video", "Paused: full screen", "Paused: game", "Paused: idle", "Stopped",
        "Colors changed", "HDR is off", "Limited by preset", "No HDR in this preset", "Little gain", "Mirrored",
        "Not supported", "Reference mode", "Checking…", "Paused: QuickTime Player", "Display Tuner may interfere",
        "Stopped: Display Tuner",
    ]

    /// Every chip Design's builder makes (empty until WP9's copy lands).
    static var builderChips: [String] {
        let reasons: [LimitReason] = [.headroom, .hdrSuppressedByMacOS, .nearFullBrightnessOnly, .safeLimit, .oledLimit,
                                      .thermalSerious, .fullScreenVideo, .fullScreenApp, .game, .oledIdle,
                                      .boostNotEnabled, .pausedApp(bundleID: "com.example.player"),
                                      .tripped(.oscillation), .tripped(.foreignTableAtLaunch),
                                      .notSupported(.turnOnHDR), .notSupported(.switchPreset), .notSupported(.lcdClass)]
        let phases: [EnginePhase] = [.arming(rung: 1), .gating(rung: 2), .failed(.headroomNeverArrived)]
        let fromReasons = reasons.compactMap { ChipModel.make(reason: $0, phase: .boosted, failedTries: 0)?.text }
        let fromPhases = phases.flatMap { phase in
            [0, 2].compactMap { ChipModel.make(reason: nil, phase: phase, failedTries: $0)?.text }
        }
        return (fromReasons + fromPhases).filter { !$0.isEmpty }
    }

    private func chip(_ text: String) -> some View {
        StatusChip(ChipModel(symbol: .exclamationMarkTriangleFill, color: .info, text: text, explanation: "",
                             accessibilityLabel: text), actions: [])
    }

    @Test func everyChipFitsItsLineInEnglish() {
        var failures: [String] = []
        for text in Self.englishChips + Self.builderChips {
            let width = FitMeasure.idealWidth(chip(text))
            if !(width > 0 && width <= PanelLayout.cardInnerWidth) { failures.append("«\(text)» \(width) pt") }
        }
        #expect(failures.isEmpty, "chips wider than \(PanelLayout.cardInnerWidth) pt: \(failures)")
    }

    @Test func everyChipFitsItsLineInThePseudoLongLocale() {
        var failures: [String] = []
        for text in (Self.englishChips + Self.builderChips).map(PseudoLocale.lengthen) {
            let width = FitMeasure.idealWidth(chip(text))
            if width > PanelLayout.cardInnerWidth { failures.append("«\(text)» \(width) pt") }
        }
        #expect(failures.isEmpty, "pseudo-long chips wider than \(PanelLayout.cardInnerWidth) pt: \(failures)")
    }

    @Test func aVeryLongAppNameStaysInsideTheLine() {
        let name = String(repeating: "Extended Professional Video Player ", count: 4)
        let width = FitMeasure.width(chip("Paused: \(name)").lineLimit(1).truncationMode(.middle),
                                     offered: PanelLayout.cardInnerWidth)
        #expect(width <= PanelLayout.cardInnerWidth)
    }

    @Test func thePseudoLocaleIsFortyPercentLonger() {
        let text = "Limited by macOS"
        let longer = FitMeasure.textWidth(PseudoLocale.lengthen(text), .caption)
        let english = FitMeasure.textWidth(text, .caption)
        #expect(longer >= english * 1.3)
    }
}
