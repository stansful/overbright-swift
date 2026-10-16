// OverbrightDisplaysTests/PanelClassTests.swift — `PanelClass` from public facts only (ARCHITECTURE.md §3.2, §10.4,
// D8), and the owner's displays built end to end from their saved CoreGraphics and IORegistry values equal the facts
// of Core's fixtures, which every other package tests with.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct PanelClassTests {
    private func classify(builtIn: Bool = false, vendor: UInt32? = 0x3669, potential: Double? = nil,
                          peak: Double? = nil, min: Double? = nil, pq: Bool? = nil) -> PanelClass {
        PanelClassifier.classify(isVirtual: false, isBuiltIn: builtIn, vendor: vendor, potential: potential,
                                 peakNits: peak, minNits: min, supportsPQ: pq)
    }

    @Test func builtInsSplitAtPotentialTwo() {
        #expect(classify(builtIn: true, potential: 16) == .builtInXDR)
        #expect(classify(builtIn: true, potential: 2) == .builtInLCD)
        #expect(classify(builtIn: true, potential: 2.005) == .builtInLCD)            // within ε = 0.01
        #expect(classify(builtIn: true, potential: 2.02) == .builtInXDR)
        #expect(classify(builtIn: true, potential: nil) == .builtInLCD)
        #expect(PanelClassifier.classify(isVirtual: true, isBuiltIn: true, vendor: 0x610, potential: 16, peakNits: 1600,
                                         minNits: nil, supportsPQ: nil) == .virtualDisplay)
    }

    @Test func externalsByVendorLuminanceAndPQ() {
        #expect(classify(vendor: PanelClassifier.appleVendor, peak: 1600, pq: true) == .appleXDRExternal)
        // An XDR's mini-LED black level must not make it an OLED.
        #expect(classify(vendor: PanelClassifier.appleVendor, peak: 2000, min: 0.0005, pq: true) == .appleXDRExternal)
        // An Apple display below 1000 nits is an ordinary external.
        #expect(classify(vendor: PanelClassifier.appleVendor, peak: 600, pq: false) == .sdrExternal)
        #expect(classify(peak: 465.49, min: 0.0003, pq: true) == .oledExternal)
        #expect(classify(peak: 465.49, min: 0.005, pq: true) == .oledExternal)
        #expect(classify(peak: 600, min: 0.05, pq: true) == .hdrExternal)
        #expect(classify(peak: 300, min: 0.3, pq: false) == .sdrExternal)
        // PQ unknown (no IORegistry, e.g. an Intel Mac): NSScreen's potential decides.
        #expect(classify(potential: 4.65, pq: nil) == .hdrExternal)
        #expect(classify(potential: 1.005, pq: nil) == .sdrExternal)
        #expect(classify(potential: nil, pq: nil) == .sdrExternal)
    }

    @Test func thePanelsOwnPotentialWinsOverThePresets() {
        // The built-in in an SDR reference preset reads 1.0 on NSScreen; EDRPotentialHeadroom still says XDR.
        let sdrPreset = RawDisplayFixtures.builtIn(potential: 1)
        let facts = DisplayFactsBuilder.facts(for: sdrPreset, registry: RawDisplayFixtures.ownerRegistry())
        #expect(facts.panelClass == .builtInXDR)
        // Without IORegistry facts NSScreen's value is all there is.
        #expect(DisplayFactsBuilder.facts(for: sdrPreset, registry: .unknown).panelClass == .builtInLCD)
    }

    @Test func theOwnersBuiltInEqualsCoresFixture() throws {
        let facts = DisplayFactsBuilder.facts(for: RawDisplayFixtures.builtIn(), registry: RawDisplayFixtures.ownerRegistry())
        let expected = try #require(DisplayFixture.builtinXDRLidOpen.displays.first).facts
        #expect(facts == expected)
    }

    @Test func theOwnersMSIMatchesCoresFixture() throws {
        for (hdr, fixture) in [(true, DisplayFixture.mpg322uxHDROn), (false, .mpg322uxHDROff)] {
            let raw = RawDisplayFixtures.msi(potential: hdr ? 4.6549 : 1)
            let facts = DisplayFactsBuilder.facts(for: raw, registry: RawDisplayFixtures.ownerRegistry())
            let expected = try #require(fixture.displays.first).facts
            #expect(facts.panelClass == .oledExternal && facts.panelClass == expected.panelClass)
            #expect(facts.ref == expected.ref && facts.name == expected.name && facts.vendorID == expected.vendorID)
            #expect(facts.supportsPQ == expected.supportsPQ && facts.gammaCapacity == expected.gammaCapacity)
            #expect(facts.productID == 19922)
            // Core's fixture rounds: peaks to 0.01 nit, the black level to 0.0001 nit.
            for (value, nits, places) in [(facts.panelPeakNits, expected.panelPeakNits, 2.0),
                                          (facts.panelFrameAverageNits, expected.panelFrameAverageNits, 2),
                                          (facts.panelMinNits, expected.panelMinNits, 4)] {
                let scale = pow(10, places)
                #expect((try #require(value) * scale).rounded() == (try #require(nits) * scale).rounded())
            }
            #expect(facts.sdrMaxNits == nil && !facts.hasNotch && !facts.isMirrored)
        }
    }
}
