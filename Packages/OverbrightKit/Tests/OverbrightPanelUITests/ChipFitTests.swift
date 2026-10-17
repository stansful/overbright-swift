// OverbrightPanelUITests/ChipFitTests.swift — status chips fit their own line: ≤ 280 pt, the card's inner width
// (DESIGN.md §5.7, §16; ARCHITECTURE.md §8.8 width rule `chip`), measured with the chip component itself, in English
// and the pseudo-long locale (+40 %), and every chip in every language Overbright ships (WP15, `ShippedLanguages`). The
// English texts are DESIGN.md §12.2's; every chip Design's builder makes for a
// reason or phase is measured too (they become the catalog's words once WP9's copy lands). App names inside a chip are
// middle-truncated to fit, so the panel's layout keeps even a very long one inside the line. The chip of a display
// whose extra brightness is off shares its line with "Turn on" only when both fit 280 pt, else "Turn on" drops under
// it (C-PANEL-4): measured together in every language.
import AppKit
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
        "Colors changed", "HDR is off", "Limited by preset", "No HDR in this preset", "Little gain", "Range unknown", "Mirrored",
        "Not supported", "Reference mode", "Checking…", "Paused: QuickTime Player", "Display Tuner may interfere",
        "Stopped: Display Tuner",
    ]

    /// Every chip Design's builder makes (empty until WP9's copy lands).
    static var builderChips: [String] {
        let reasons: [LimitReason] = [.headroom, .hdrSuppressedByMacOS, .nearFullBrightnessOnly, .safeLimit, .oledLimit,
                                      .thermalSerious, .fullScreenVideo, .fullScreenApp, .game, .oledIdle,
                                      .boostNotEnabled, .pausedApp(bundleID: "com.example.player"),
                                      .tripped(.oscillation), .tripped(.foreignTableAtLaunch),
                                      .notSupported(.turnOnHDR), .notSupported(.switchPreset), .notSupported(.lcdClass),
                                      .notSupported(.panelFactsUnknown)]
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

    // MARK: Every language (WP15)

    /// The apps the measured chips name: DESIGN.md §12.2's examples.
    nonisolated static let mayInterfere = ConflictingApp(entryID: "s3", severity: .conditional,
                                                          bundleID: "com.example.tuner", processID: 3,
                                                          displayName: "Display Tuner")
    nonisolated static let colorApp = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: "com.example.tuner",
                                                      processID: 2, displayName: "Display Tuner")

    /// Every chip Design's builders make in `language`: each per-display reason, the engine phases, and the badge of
    /// every verdict that cannot boost (the chip of a dim-only display).
    static func chips(in language: CopyLanguage) -> [String] {
        let context = ChipContext(allowedGain: 1.55, appName: "QuickTime Player", language: language)
        let reasons: [LimitReason] = [.headroom, .hdrSuppressedByMacOS, .nearFullBrightnessOnly, .safeLimit, .oledLimit,
                                      .thermalSerious, .fullScreenVideo, .fullScreenApp, .game, .oledIdle,
                                      .boostNotEnabled, .pausedApp(bundleID: "com.apple.QuickTimePlayerX"),
                                      .conflict(mayInterfere), .tripped(.oscillation),
                                      .tripped(.attributedDrift(colorApp)), .tripped(.foreignTableAtLaunch)]
        let phases: [EnginePhase] = [.arming(rung: 1), .failed(.headroomNeverArrived)]
        let verdicts: [DisplayVerdict] = [.checking, .turnOnHDR, .switchPreset, .referencePreset, .lcdClass, .mirrored,
                                          .virtualDisplay, .noGammaTable, .notHDR, .panelFactsUnknown]
        let fromReasons = reasons.compactMap {
            ChipModel.make(reason: $0, phase: .boosted, failedTries: 0, context: context)?.text
        }
        let fromPhases = phases.compactMap {
            ChipModel.make(reason: nil, phase: $0, failedTries: 2, context: context)?.text
        }
        let badges = verdicts.compactMap { ChipModel.verdict($0, in: language)?.text }
        return (fromReasons + fromPhases + badges).filter { !$0.isEmpty }
    }

    /// The fit tests below run every language of `scripts/l10n/languages.json`, and Design's catalog ships each one.
    @Test func everyShippedLanguageIsMeasured() throws {
        #expect(ShippedLanguages.codes == (try ShippedLanguages.listed()))
        #expect(ShippedLanguages.codes.count == 35)
        for code in ShippedLanguages.codes {
            #expect(ShippedLanguages.design(code)?.bundle.bundleURL.lastPathComponent == "\(code).lproj", "\(code)")
            #expect(ShippedLanguages.panel(code)?.bundleURL.lastPathComponent == "\(code).lproj", "\(code)")
        }
        #expect(ShippedLanguages.design("tlh") == nil && ShippedLanguages.panel("tlh") == nil)   // never English instead
    }

    /// "Extra brightness off" and "Turn on" stay inside the card in every language: on one line when both fit, else
    /// the button under the chip.
    @Test(arguments: ShippedLanguages.codes)
    func theChipAndTurnOnStayInsideTheCardInEveryLanguage(_ code: String) throws {
        let language = try #require(ShippedLanguages.design(code), "\(code): no Design table")
        let chip = try #require(ChipModel.make(reason: .boostNotEnabled, phase: .idle, failedTries: 0,
                                               context: ChipContext(language: language)))
        let title = try #require(PanelWords(code), "\(code): no PanelUI table").turnOn
        func button() -> some View {
            Button {} label: { Text(verbatim: title) }.buttonStyle(OverbrightLinkButtonStyle())
        }
        let chipWidth = FitMeasure.idealWidth(StatusChip(chip, actions: []))
        let buttonWidth = FitMeasure.idealWidth(button())
        #expect(chipWidth <= PanelLayout.cardInnerWidth && buttonWidth <= PanelLayout.cardInnerWidth, "\(code)")
        let line = CardChipLine { StatusChip(chip, actions: []) } turnOn: { button() }
        let size = NSHostingView(rootView: line.fixedSize()).fittingSize
        #expect(size.width == PanelLayout.cardInnerWidth, "\(code): \(size.width) pt")
        let oneLine = chipWidth + Space.s + buttonWidth <= PanelLayout.cardInnerWidth
        let lineHeight = max(StatusChip.height, FitMeasure.idealHeight(button()))
        #expect(oneLine ? size.height <= lineHeight + 1 : size.height > lineHeight + Space.xxs,
                "\(code): «\(chip.text)» \(chipWidth) pt + «\(title)» \(buttonWidth) pt, \(size.height) pt high")
        if code == "en" { #expect(oneLine) }
    }

    @Test(arguments: ShippedLanguages.codes)
    func everyChipFitsItsLineInEveryLanguage(_ code: String) throws {
        let language = try #require(ShippedLanguages.design(code), "\(code): no Design table")
        let texts = Self.chips(in: language)
        #expect(texts.count >= 25, "\(code): \(texts.count) chips")
        var failures: [String] = []
        for text in texts {
            let width = FitMeasure.idealWidth(chip(text))
            if !(width > 0 && width <= PanelLayout.cardInnerWidth) { failures.append("«\(text)» \(width) pt") }
        }
        #expect(failures.isEmpty, "\(code): chips wider than \(PanelLayout.cardInnerWidth) pt: \(failures)")
    }
}
