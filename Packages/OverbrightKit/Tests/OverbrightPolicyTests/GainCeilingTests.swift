// OverbrightPolicyTests/GainCeilingTests.swift — the interlock's live cap and the small ceiling helpers.
// ARCHITECTURE.md §5.4, §5.6, §9.1. (`sliderTop` is WP1's.)
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct GainCeilingTests {
    private let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private func reading(_ h: Double) -> HeadroomReading {
        HeadroomReading(display: 1, current: h, potential: 16, reference: 0, time: MonotonicInstant(sinceOrigin: .zero))
    }
    private func facts(_ panelClass: PanelClass, peak: Double?) -> DisplayFacts {
        DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "x"), id: 9), name: "", isBuiltIn: false, gammaCapacity: 256,
                     panelPeakNits: peak, sdrMaxNits: 300, panelClass: panelClass)
    }

    @Test func capNitsPerClass() {
        #expect(GainCeiling.capNits(facts: builtIn, isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.appleXDRExternal, peak: 2000), isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: 600), isOLED: false) == 360)       // 0.6 × peak
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: 4000), isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: nil), isOLED: false) == nil)
        #expect(GainCeiling.capNits(facts: builtIn, isOLED: true) == nil)                               // OLED: ×1.3
        #expect(GainCeiling.capNits(facts: facts(.sdrExternal, peak: 300), isOLED: false) == nil)
    }

    @Test func fullBrightnessSeedAndTaper() throws {
        #expect(abs(try #require(GainCeiling.fullBrightnessHeadroomSeed(facts: builtIn)) - 1600.0 / 600) < 1e-12)
        #expect(GainCeiling.fullBrightnessHeadroomSeed(facts: facts(.hdrExternal, peak: nil)) == nil)
        #expect(GainCeiling.taperExponent(headroom: 2.667, fullBrightnessHeadroom: 2.667) == 1)
        #expect(GainCeiling.taperExponent(headroom: 1.15 * 2.667, fullBrightnessHeadroom: 2.667) == 1)
        #expect(abs(GainCeiling.taperExponent(headroom: 1.575 * 2.667, fullBrightnessHeadroom: 2.667) - 0.5) < 1e-9)
        #expect(GainCeiling.taperExponent(headroom: 2 * 2.667, fullBrightnessHeadroom: 2.667) == 0)
        #expect(GainCeiling.taperExponent(headroom: 9, fullBrightnessHeadroom: 0.5) == 0)                // ref floored at 1
    }

    /// §5.6: the M4 Max built-in indoors, outdoors and at half brightness.
    @Test func workedLiveCaps() {
        func cap(_ g: Double, h: Double, mode: CapMode, taper: Bool = true, sdr: SDRWhiteEstimate? = nil) -> GainCeiling.LiveCap {
            GainCeiling.liveCap(staticGain: g, reading: reading(h), facts: builtIn, capMode: mode, isOLED: false,
                                sdrWhite: sdr, taper: taper, fullBrightnessHeadroom: 1600.0 / 600)
        }
        #expect(abs(cap(1000.0 / 600, h: 1600.0 / 600, mode: .safe).gain - 1.667) < 0.001)              // indoors, Safe
        #expect(abs(cap(0.97 * 1600 / 600, h: 1600.0 / 600, mode: .peak).gain - 2.587) < 0.001)         // indoors, Peak
        let outdoors = cap(1000.0 / 600, h: 1.6, mode: .safe)                                           // SDR 1000 nits
        #expect(outdoors.gain == 1 && outdoors.reason == .safeLimit)
        let outdoorsPeak = cap(0.97 * 1600 / 600, h: 1.6, mode: .peak)
        #expect(abs(outdoorsPeak.gain - 1.552) < 1e-9 && outdoorsPeak.reason == .headroom)
        let half = cap(1000.0 / 600, h: 1600.0 / 300, mode: .safe)                                       // taper: none
        #expect(half.gain == 1 && half.reason == .nearFullBrightnessOnly)
        let halfNoTaper = cap(1000.0 / 600, h: 1600.0 / 300, mode: .safe, taper: false)
        #expect(abs(halfNoTaper.gain - 1.667) < 0.001 && halfNoTaper.reason == nil)
        // With a trusted SDR white the live Safe bound is skipped (the reducer's static term is exact).
        let trusted = cap(1.5, h: 1.6, mode: .safe, sdr: SDRWhiteEstimate(nits: 600, source: .colorimeter))
        #expect(abs(trusted.gain - 1.5) < 1e-12 && trusted.reason == nil)
    }

    /// Property: liveCap never exceeds 0.97·H, nor capNits·H/panelPeak in Safe without an SDR estimate (or 1).
    @Test func liveCapNeverExceedsItsBounds() {
        var random = SeededGenerator(seed: 0xCA9)
        let displays = [builtIn, facts(.hdrExternal, peak: 600), facts(.appleXDRExternal, peak: 2000),
                        DisplayFixture.mpg322uxHDROn.displays[0].facts]
        for _ in 0..<20_000 {
            let facts = displays.randomElement(using: &random) ?? builtIn
            let h = Double.random(in: 1...16, using: &random)
            let mode: CapMode = Bool.random(using: &random) ? .safe : .peak
            let isOLED = facts.panelClass == .oledExternal
            let result = GainCeiling.liveCap(staticGain: Double.random(in: 1...16, using: &random), reading: reading(h),
                                             facts: facts, capMode: mode, isOLED: isOLED, sdrWhite: nil,
                                             taper: Bool.random(using: &random),
                                             fullBrightnessHeadroom: Double.random(in: 1...4, using: &random))
            #expect(result.gain >= 1)
            #expect(result.gain <= max(1, FactorMath.headroomMargin * h) + 1e-12)
            if mode == .safe, let nits = GainCeiling.capNits(facts: facts, isOLED: isOLED), let peak = facts.panelPeakNits {
                #expect(result.gain <= max(1, nits * h / peak) + 1e-12)
            }
        }
    }
}
