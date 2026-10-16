// OverbrightDesignTests/VerdictTextTests.swift — DESIGN.md §12.1: every verdict's badge, sentence and fix in exact
// English, the Safe and Peak variants, the grant macOS gave, the advisories; and the class-specific Safe sentences of
// §12.2. A supported verdict quotes the default (Safe) ceiling, never the raw potential (D8).
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightDesign

@Suite struct VerdictTextTests {
    private func words(_ verdict: DisplayVerdict, advisories: [Advisory] = [], grant: Double? = nil,
                       capMode: CapMode = .safe) -> VerdictText {
        VerdictText.make(verdict, advisories: advisories, lastGrant: grant, capMode: capMode, in: english)
    }

    @Test func supportedQuotesSafeThenPeak() {
        let safe = words(.supported(safeGain: 1.667, peakGain: 2.587))
        #expect(safe.badge == "Supported")
        #expect(safe.sentence == "With Safe, up to about 1.7× brighter at full brightness. Peak can go further when macOS allows it.")
        #expect(safe.fix == nil && safe.fixTitle == nil)
        let peak = words(.supported(safeGain: 1.667, peakGain: 2.587), capMode: .peak)
        #expect(peak.sentence == "With Peak, up to about 2.6× brighter at full brightness, when macOS allows it.")
    }

    @Test func supportedAddsTheGrantMacOSGave() {
        let words = words(.supported(safeGain: 1.667, peakGain: 2.587), grant: 1.55)
        #expect(words.sentence == "With Safe, up to about 1.7× brighter at full brightness. macOS allowed up to ×1.55 on this display last time.")
        let peak = self.words(.supported(safeGain: 1.667, peakGain: 2.587), grant: 1.55, capMode: .peak)
        #expect(peak.sentence.hasSuffix("when macOS allows it. macOS allowed up to ×1.55 on this display last time."))
    }

    /// Studio Display XDR: Safe adds nothing; the verdict quotes Peak and offers Choose Peak….
    @Test func safeAddsNothingOffersPeak() {
        let studio = words(.supported(safeGain: nil, peakGain: 1.94))
        #expect(studio.sentence == "Safe adds no extra brightness on this display, because its normal maximum already reaches the level it can hold across the whole screen. With Peak, up to about 1.9× brighter at full brightness, when macOS allows it.")
        #expect(studio.fix == .choosePeak && studio.fixTitle == "Choose Peak…")
        let peak = words(.supported(safeGain: nil, peakGain: 1.94), capMode: .peak)
        #expect(peak.fix == nil)
    }

    /// The rest of the table of DESIGN.md §12.1.
    @Test func theVerdictTable() {
        typealias Row = (DisplayVerdict, String, String, FixAction?)
        let rows: [Row] = [
            (.noGainAtFullBrightness(peakGain: 1.05), "Little gain",
             "At full brightness this display gains less than 10%. Raising the display brightness gives the same result.", nil),
            (.presetLimits(presetPeakNits: 600, panelPeakNits: 1600), "Limited by preset",
             "The current preset stops at about 600 nits. Choose a preset with a higher peak, such as 1,600 nits, in Displays settings.",
             .openSystemSettings),
            (.turnOnHDR, "HDR is off",
             "Turn on High Dynamic Range for this display in Displays settings to use extra brightness. This changes how everyday content looks on some displays. You can turn it off again at any time. You can still dim it below the minimum.",
             .openSystemSettings),
            (.switchPreset, "No HDR in this preset",
             "This preset doesn’t allow extra brightness. Choose a preset with a higher peak in Displays settings. You can still dim it below the minimum.",
             .openSystemSettings),
            (.referencePreset, "Reference mode",
             "A reference preset is active. Overbright leaves reference modes as they are.", .openSystemSettings),
            (.lcdClass, "Not supported",
             "This display has no extra brightness range. You can still dim it below the minimum.", nil),
            (.notHDR, "Not supported",
             "This display doesn’t support HDR, so it has no extra range. You can still dim it below the minimum.", nil),
            (.mirrored, "Mirrored", "This display mirrors another one, so Overbright can only dim it.", nil),
            (.virtualDisplay, "Not supported", "Sidecar and AirPlay displays can’t be adjusted.", nil),
            (.noGammaTable, "Not supported", "macOS doesn’t let apps adjust this display.", nil),
            (.checking, "Checking…", "Overbright is reading this display.", nil),
        ]
        for (verdict, badge, sentence, fix) in rows {
            let text = words(verdict)
            #expect(text.badge == badge, "\(verdict)")
            #expect(text.sentence == sentence, "\(verdict)")
            #expect(text.fix == fix, "\(verdict)")
            #expect(text.fixTitle == fix?.title(in: english), "\(verdict)")
        }
    }

    @Test func advisoriesFollowTheVerdictInOrder() {
        let text = words(.supported(safeGain: 1.3, peakGain: 1.7), advisories: [.oledCare, .notCalibrated])
        #expect(text.advisories == [
            "OLED display: extra brightness stays lower and pauses after 5 minutes without input.",
            "Not calibrated. Numbers are estimates, and Overbright uses a safe default.",
        ])
        #expect(VerdictText.line(for: .compatibilityModeAdvised, in: english)
                == "On this Mac, macOS ignores color table changes, so Overbright uses Compatibility mode.")
        #expect(VerdictText.line(for: .autoBrightnessInteracts, in: english).hasPrefix("Keep Automatically adjust brightness"))
        #expect(VerdictText.line(for: .oledCare, oledIdleMinutes: 10, in: english).contains("10 minutes"))
    }

    /// Every verdict has words, and no verdict quotes a number it did not get (the potential is never an input).
    @Test func everyVerdictHasWords() {
        let all: [DisplayVerdict] = [.checking, .supported(safeGain: 1.5, peakGain: 2), .noGainAtFullBrightness(peakGain: 1.05),
                                     .presetLimits(presetPeakNits: 600, panelPeakNits: 1600), .turnOnHDR, .switchPreset,
                                     .referencePreset, .lcdClass, .mirrored, .virtualDisplay, .noGammaTable, .notHDR]
        for verdict in all {
            let text = VerdictText.make(verdict, advisories: [], lastGrant: nil)
            #expect(!text.badge.isEmpty && !text.sentence.isEmpty, "\(verdict)")
        }
    }

    /// DESIGN.md §12.2, the Safe sentences by class (also the Limit footnote).
    @Test func safeSentencesByClass() {
        func safe(_ cls: PanelClass, oled: Bool = false, top: Double? = 1.667, sdr: Double? = nil, bright: Bool = false,
                  bound: GainCeilingBound = .worst) -> String {
            SafeLimitText(panelClass: cls, isOLED: oled, safeTop: top, sdrWhiteNits: sdr, liveBoundBelowTop: bright,
                          safeBound: bound == .worst ? .worstCaseGrant : .sliderTopOnly).sentence(in: english)
        }
        #expect(safe(.builtInXDR) == "Safe stays at the level this display can hold across the whole screen, ×1.67 here.")
        #expect(safe(.appleXDRExternal, sdr: 600)
                == "Safe stays at the level this display can hold across the whole screen, ×1.67 here, about 1,000 nits.")
        #expect(safe(.builtInXDR, bright: true)
                == "Safe stays at the level this display can hold across the whole screen. In bright surroundings macOS already shows white that bright, so Safe adds nothing now.")
        #expect(safe(.hdrExternal, top: 1.4) == "Safe stays at ×1.40 here, about what this display can hold across the whole screen.")
        #expect(safe(.oledExternal, oled: true, top: 1.3) == "Safe stops at 1.3 times on OLED displays.")
        #expect(safe(.appleXDRExternal, top: nil)
                == "Safe adds no extra brightness on this display, because its normal maximum already reaches the level it can hold across the whole screen.")
        #expect(safe(.builtInXDR, bound: .topOnly) == "Safe stays at ×1.67 here.")
    }

    enum GainCeilingBound { case worst, topOnly }
}
