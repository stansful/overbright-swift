// OverbrightPolicyTests/GainCeilingTests.swift — the slider tops per class (§5.3), the interlock's live cap (§5.4) and
// every row of the worked numbers (§5.6), to 3 decimals. ARCHITECTURE.md §5.3, §5.4, §5.6, §9.1.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct GainCeilingTests {
    private let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private let proDisplay = DisplayFixture.proDisplayXDR.displays[0].facts
    private let studio = DisplayFixture.studioDisplayXDR.displays[0].facts
    private let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts

    private func reading(_ h: Double, display: CGDirectDisplayID = 1) -> HeadroomReading {
        HeadroomReading(display: display, current: h, potential: 16, reference: 0, time: MonotonicInstant(sinceOrigin: .zero))
    }
    private func facts(_ panelClass: PanelClass, peak: Double?, sdrMax: Double? = 300, frameAverage: Double? = nil,
                       builtIn: Bool = false) -> DisplayFacts {
        DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "x"), id: 9), name: "", isBuiltIn: builtIn,
                     gammaCapacity: 256, panelPeakNits: peak, panelFrameAverageNits: frameAverage, sdrMaxNits: sdrMax,
                     panelClass: panelClass)
    }
    private func top(_ facts: DisplayFacts, _ mode: CapMode, oled: Bool = false) -> Double {
        GainCeiling.sliderTop(facts: facts, capMode: mode, isOLED: oled)
    }
    /// To 3 decimals: the value rounds to `expected`.
    private func close(_ value: Double, _ expected: Double) -> Bool { abs(value - expected) < 0.0005 }

    @Test func capNitsPerClass() {
        #expect(GainCeiling.capNits(facts: builtIn, isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.appleXDRExternal, peak: 2000), isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: 600), isOLED: false) == 360)       // 0.6 × peak
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: 4000), isOLED: false) == 1000)
        #expect(GainCeiling.capNits(facts: facts(.hdrExternal, peak: nil), isOLED: false) == nil)
        #expect(GainCeiling.capNits(facts: builtIn, isOLED: true) == nil)                               // OLED: ×1.3
        #expect(GainCeiling.capNits(facts: facts(.sdrExternal, peak: 300), isOLED: false) == nil)
        // An OLED-class external the user marked "Not OLED" is an other HDR external (D8: override first).
        #expect(abs((GainCeiling.capNits(facts: msi, isOLED: false) ?? 0) - 0.6 * 465.49) < 1e-9)
        #expect(GainCeiling.capNits(facts: msi, isOLED: true) == nil)
    }

    /// §5.3 "Display class | Safe top | Peak top" and the rows of "Presets per class".
    @Test func sliderTopsPerClass() {
        #expect(close(top(builtIn, .safe), 1.667) && close(top(builtIn, .peak), 2.587))           // M4 Max built-in
        let m1 = facts(.builtInXDR, peak: 1600, sdrMax: 500, builtIn: true)                       // M1/M2 MacBook Pro
        #expect(close(top(m1, .safe), 2.000) && close(top(m1, .peak), 3.104))
        #expect(close(top(proDisplay, .safe), 2.000) && close(top(proDisplay, .peak), 3.104))
        #expect(top(studio, .safe) == 1 && close(top(studio, .peak), 1.940))                      // no Safe boost
        #expect(close(top(msi, .safe, oled: true), 1.300) && close(top(msi, .peak, oled: true), 1.704))
        let hdr600 = facts(.hdrExternal, peak: 600, sdrMax: 300)                                  // DisplayHDR 600
        #expect(close(top(hdr600, .safe), 1.200) && close(top(hdr600, .peak), 1.940))
        // The SDR maximum of an external without one is its frame average (§5.1), never on a built-in.
        #expect(GainCeiling.sdrMaxNits(facts: msi) == 265.05)
        #expect(GainCeiling.sdrMaxNits(facts: facts(.builtInXDR, peak: 1600, sdrMax: nil, frameAverage: 500,
                                                    builtIn: true)) == nil)
        #expect(GainCeiling.sdrMaxNits(facts: facts(.hdrExternal, peak: 600, sdrMax: 0)) == nil)
    }

    /// An Apple XDR external's frame average is its full-screen sustained HDR level, never its SDR maximum: without
    /// the product's SDR maximum it has none (and no top), instead of ×1.55 Peak and no Safe (C-PLATFORM-1).
    @Test func anAppleXDRExternalNeverTakesItsFrameAverageAsSDRWhite() {
        #expect(proDisplay.panelFrameAverageNits == 1000 && GainCeiling.sdrMaxNits(facts: proDisplay) == 500)
        let unknownProduct = facts(.appleXDRExternal, peak: 1600, sdrMax: nil, frameAverage: 1000)
        #expect(GainCeiling.frameAverageSDRWhite(facts: unknownProduct) == nil)
        #expect(GainCeiling.sdrMaxNits(facts: unknownProduct) == nil)
        #expect(top(unknownProduct, .peak) == 1 && top(unknownProduct, .safe) == 1)
        // Other externals keep the HDR-mode SDR white; a built-in never has one.
        #expect(GainCeiling.frameAverageSDRWhite(facts: msi) == 265.05)
        #expect(GainCeiling.frameAverageSDRWhite(facts: facts(.hdrExternal, peak: 600, frameAverage: 300)) == 300)
        #expect(GainCeiling.frameAverageSDRWhite(facts: facts(.builtInXDR, peak: 1600, frameAverage: 500,
                                                              builtIn: true)) == nil)
        #expect(GainCeiling.frameAverageSDRWhite(facts: facts(.hdrExternal, peak: 600, frameAverage: 0)) == nil)
        // The seed of the taper's reference uses the facts' SDR maximum: 1600 ÷ 500 on the Pro Display XDR.
        #expect(GainCeiling.fullBrightnessHeadroomSeed(facts: proDisplay) == 3.2)
    }

    /// A top below ×1.05 disables that half (answered as 1); classes that never boost and unknown panel facts give 1.
    @Test func sliderTopIsOneWhereTheBoostHalfIsDisabledOrUnknown() {
        let dim = facts(.hdrExternal, peak: 400, sdrMax: 300)
        #expect(top(dim, .safe) == 1 && close(top(dim, .peak), 1.293))         // Safe 240 ÷ 300 < 1
        #expect(top(facts(.hdrExternal, peak: 320, sdrMax: 300), .peak) == 1)    // 1.035 < 1.05
        #expect(top(facts(.hdrExternal, peak: 326, sdrMax: 300), .peak) > 1.05)
        for panelClass in [PanelClass.builtInLCD, .sdrExternal, .virtualDisplay] {
            #expect(top(facts(panelClass, peak: 1600, sdrMax: 500), .peak) == 1, "\(panelClass)")
            #expect(top(facts(panelClass, peak: 1600, sdrMax: 500), .safe, oled: true) == 1, "\(panelClass)")
        }
        #expect(top(facts(.builtInXDR, peak: nil, sdrMax: 600, builtIn: true), .peak) == 1)
        #expect(top(facts(.builtInXDR, peak: 1600, sdrMax: nil, builtIn: true), .peak) == 1)
        #expect(top(facts(.hdrExternal, peak: 600, sdrMax: nil), .safe) == 1)
        // The OLED override: an HDR external treated as OLED gets ×1.3; an OLED marked "Not OLED" the HDR rule.
        #expect(close(top(facts(.hdrExternal, peak: 1000, sdrMax: 400), .safe, oled: true), 1.300))
        #expect(close(top(msi, .safe, oled: false), min(0.6 * 465.49, 0.97 * 465.49) / 265.05))
        // Every top lies in [1, Peak].
        for mode in CapMode.allCases {
            for display in [builtIn, proDisplay, studio, msi] {
                #expect(top(display, mode) >= 1 && top(display, mode) <= top(display, .peak))
            }
        }
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

    /// The taper's reference never falls below the seed `panelPeak ÷ sdrMax` (2026-10-20). On the owner's MacBook Pro
    /// the strategy cache's lowest ready H was 1.31, a reading taken while the grant still ramped from 1.2 to 4.0;
    /// compared with it, H 4.0 read as "far below full brightness" and the taper cut every boost to ×1. Floored at the
    /// seed 2.67 the same H keeps a boost; a measured reference above the seed is used as it is.
    @Test func taperReferenceNeverBelowTheSeed() throws {
        let seed = 1600.0 / 600
        #expect(abs(try #require(GainCeiling.taperReference(measured: 1.31, facts: builtIn)) - seed) < 1e-12)
        #expect(abs(try #require(GainCeiling.taperReference(measured: nil, facts: builtIn)) - seed) < 1e-12)
        #expect(GainCeiling.taperReference(measured: 3.2, facts: builtIn) == 3.2)
        let unknownPeak = facts(.hdrExternal, peak: nil)
        #expect(GainCeiling.taperReference(measured: 1.31, facts: unknownPeak) == 1.31)
        #expect(GainCeiling.taperReference(measured: nil, facts: unknownPeak) == nil)
        // Against 1.31, H 4.0 is past twice the reference: t = 0, no boost at all.
        #expect(GainCeiling.taperExponent(headroom: 4.0, fullBrightnessHeadroom: 1.31) == 0)
        for mode in CapMode.allCases {
            let measured = GainCeiling.liveCap(staticGain: top(builtIn, mode), reading: reading(4.0), facts: builtIn,
                                               capMode: mode, isOLED: false, sdrWhite: nil, taper: true,
                                               fullBrightnessHeadroom: 1.31)
            let seeded = GainCeiling.liveCap(staticGain: top(builtIn, mode), reading: reading(4.0), facts: builtIn,
                                             capMode: mode, isOLED: false, sdrWhite: nil, taper: true,
                                             fullBrightnessHeadroom: seed)
            #expect(measured.gain > 1, "\(mode)")
            #expect(measured == seeded, "\(mode)")
            #expect(measured.reason == .nearFullBrightnessOnly, "\(mode)")
        }
    }

    /// §5.4: the M4 Max built-in at 75 % brightness (SDR 450) gets ≈ 670 nits at Safe with the taper on.
    @Test func taperAtThreeQuarterBrightness() {
        let cap = GainCeiling.liveCap(staticGain: top(builtIn, .safe), reading: reading(1600.0 / 450), facts: builtIn,
                                      capMode: .safe, isOLED: false, sdrWhite: nil, taper: true,
                                      fullBrightnessHeadroom: 1600.0 / 600)
        #expect(abs(cap.gain * 450 - 670) < 3 && cap.reason == .nearFullBrightnessOnly)
    }

    /// Every row of §5.6 "Worked numbers": Safe and Peak G → F and nits, the taper, and "if linear" (F × SDR white).
    @Test func workedNumbers() {
        struct Row {
            var name: String
            var facts: DisplayFacts
            var oled: Bool
            var sdr: Double
            var h: Double
            var taper: Bool
            var safe: (g: Double, f: Double, nits: Double, linearNits: Double)?
            var peak: (g: Double, f: Double, nits: Double, linearNits: Double)
        }
        let rows = [
            Row(name: "M4 Max indoors", facts: builtIn, oled: false, sdr: 600, h: 1600.0 / 600, taper: true,
                safe: (1.667, 1.237, 1000, 742), peak: (2.587, 1.486, 1552, 892)),
            Row(name: "M4 Max outdoors", facts: builtIn, oled: false, sdr: 1000, h: 1.6, taper: true,
                safe: nil, peak: (1.552, 1.201, 1552, 1201)),
            Row(name: "M4 Max half brightness, taper off", facts: builtIn, oled: false, sdr: 300, h: 1600.0 / 300,
                taper: false, safe: (1.667, 1.237, 500, 371), peak: (2.587, 1.486, 776, 446)),
            Row(name: "Pro Display XDR", facts: proDisplay, oled: false, sdr: 500, h: 3.2, taper: true,
                safe: (2.000, 1.335, 1000, 667), peak: (3.104, 1.603, 1552, 802)),
            Row(name: "Studio Display XDR", facts: studio, oled: false, sdr: 1000, h: 2.0, taper: true,
                safe: nil, peak: (1.940, 1.318, 1940, 1318)),
            Row(name: "Studio Display XDR half, taper off", facts: studio, oled: false, sdr: 500, h: 4.0, taper: false,
                safe: nil, peak: (1.940, 1.318, 970, 659)),
            Row(name: "MSI HDR on", facts: msi, oled: true, sdr: 265.05, h: 465.49 / 265.05, taper: true,
                safe: (1.300, 1.116, 345, 296), peak: (1.704, 1.249, 452, 331)),
        ]
        for row in rows {
            for mode in CapMode.allCases {
                let cap = GainCeiling.liveCap(staticGain: top(row.facts, mode, oled: row.oled),
                                              reading: reading(row.h, display: row.facts.ref.id), facts: row.facts,
                                              capMode: mode, isOLED: row.oled, sdrWhite: nil, taper: row.taper,
                                              fullBrightnessHeadroom: GainCeiling.fullBrightnessHeadroomSeed(facts: row.facts))
                let f = FactorMath.tableFactor(forLightGain: cap.gain, domain: .encoded)
                guard let expected = mode == .safe ? row.safe : row.peak else {
                    #expect(cap.gain == 1, "\(row.name): no Safe boost")
                    continue
                }
                #expect(close(cap.gain, expected.g), "\(row.name) \(mode): G \(cap.gain)")
                #expect(close(f, expected.f), "\(row.name) \(mode): F \(f)")
                #expect((cap.gain * row.sdr).rounded() == expected.nits, "\(row.name) \(mode): nits")
                #expect((f * row.sdr).rounded() == expected.linearNits, "\(row.name) \(mode): if linear")
            }
        }
        // Outdoors, Safe adds nothing whether bounded live (no SDR estimate) …
        let outdoors = GainCeiling.liveCap(staticGain: top(builtIn, .safe), reading: reading(1.6), facts: builtIn,
                                           capMode: .safe, isOLED: false, sdrWhite: nil, taper: true,
                                           fullBrightnessHeadroom: 1600.0 / 600)
        #expect(outdoors.gain == 1 && outdoors.reason == .safeLimit)
        // … and at half brightness with the taper on (default), neither mode boosts: t = 0.
        for (facts, h) in [(builtIn, 1600.0 / 300), (studio, 4.0)] {
            for mode in CapMode.allCases {
                let cap = GainCeiling.liveCap(staticGain: top(facts, mode), reading: reading(h), facts: facts,
                                              capMode: mode, isOLED: false, sdrWhite: nil, taper: true,
                                              fullBrightnessHeadroom: GainCeiling.fullBrightnessHeadroomSeed(facts: facts))
                #expect(cap.gain == 1)
            }
        }
    }

    /// At exactly the grant, Peak's top and 0.97 × H tie to the last bit: the gain is the minimum, and no live term
    /// is reported as a limit; a real limit (one step below) is.
    @Test func aTieAtTheGrantIsNotALimit() {
        let atGrant = GainCeiling.liveCap(staticGain: top(builtIn, .peak), reading: reading(1600.0 / 600), facts: builtIn,
                                          capMode: .peak, isOLED: false, sdrWhite: nil, taper: true,
                                          fullBrightnessHeadroom: 1600.0 / 600)
        #expect(atGrant.reason == nil && close(atGrant.gain, 2.587))
        #expect(atGrant.gain <= FactorMath.headroomMargin * 1600.0 / 600)
        let below = GainCeiling.liveCap(staticGain: top(builtIn, .peak), reading: reading(2.6), facts: builtIn,
                                        capMode: .peak, isOLED: false, sdrWhite: nil, taper: true,
                                        fullBrightnessHeadroom: 1600.0 / 600)
        #expect(below.reason == .headroom && below.gain == FactorMath.headroomMargin * 2.6)
    }

    /// §5.4 with a trusted SDR white, the live Safe bound is skipped (the reducer's static term is exact).
    @Test func liveCapSkipsTheSafeBoundWithATrustedSDRWhite() {
        let trusted = GainCeiling.liveCap(staticGain: 1.5, reading: reading(1.6), facts: builtIn, capMode: .safe,
                                          isOLED: false, sdrWhite: SDRWhiteEstimate(nits: 600, source: .colorimeter),
                                          taper: true, fullBrightnessHeadroom: 1600.0 / 600)
        #expect(abs(trusted.gain - 1.5) < 1e-12 && trusted.reason == nil)
    }

    /// Property: liveCap never exceeds 0.97·H, nor capNits·H/panelPeak in Safe without an SDR estimate (or 1).
    @Test func liveCapNeverExceedsItsBounds() {
        var random = SeededGenerator(seed: 0xCA9)
        let displays = [builtIn, facts(.hdrExternal, peak: 600), facts(.appleXDRExternal, peak: 2000), msi]
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
