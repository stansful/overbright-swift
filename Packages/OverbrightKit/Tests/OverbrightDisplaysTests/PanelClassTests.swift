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

    /// Every Policy test of an Apple XDR external runs on Core's fixtures; the live builder must produce exactly those
    /// facts from what CoreGraphics and the IORegistry report, the SDR maximum included (C-PLATFORM-1).
    @Test func theAppleXDRExternalsEqualCoresFixtures() throws {
        let cases = [(DisplayFixture.proDisplayXDR, RawDisplayFixtures.proDisplay, RawDisplayFixtures.proDisplayAttributes),
                     (.studioDisplayXDR, RawDisplayFixtures.studioDisplay, RawDisplayFixtures.studioDisplayAttributes)]
        for (fixture, raw, attributes) in cases {
            let registry = RawDisplayFixtures.ownerRegistry(extra: [attributes])
            let facts = DisplayFactsBuilder.facts(for: raw, registry: registry)
            let expected = try #require(fixture.displays.first).facts
            #expect(facts == expected, "\(fixture)")
        }
    }

    /// The SDR maximum of an Apple XDR external is the product's (500 / 1000 nits), whatever its frame average says;
    /// an Apple display the table does not know gets none; nothing else gets one from the table.
    @Test func anAppleXDRExternalsSDRMaximumComesFromTheProduct() {
        var registry = RawDisplayFixtures.ownerRegistry(extra: [RawDisplayFixtures.proDisplayAttributes])
        let pro = DisplayFactsBuilder.facts(for: RawDisplayFixtures.proDisplay, registry: registry)
        #expect(pro.sdrMaxNits == 500 && pro.panelFrameAverageNits == 1000 && pro.panelClass == .appleXDRExternal)
        // Every Pro Display XDR and Studio Display XDR product ID macOS lists.
        for product in [0xAE21, 0xAE22, 0xAE23, 0xAE2D, 0xAE2E, 0xAE2F] as [UInt32] {
            #expect(AppleXDRProducts.product(vendor: 0x610, product: product)?.sdrMaxNits == 500)
        }
        for product in [0xAE42, 0xAE43] as [UInt32] {
            #expect(AppleXDRProducts.product(vendor: 0x610, product: product)?.sdrMaxNits == 1000)
        }
        #expect(AppleXDRProducts.product(vendor: 0x3669, product: 0xAE2F) == nil)          // another vendor
        // An Apple XDR-class display with a product the table does not know: no SDR maximum, never the frame average.
        var unknown = RawDisplayFixtures.proDisplay
        unknown.model = 0xAEFF
        var attributes = RawDisplayFixtures.proDisplayAttributes
        attributes.productID = 0xAEFF
        registry = RawDisplayFixtures.ownerRegistry(extra: [attributes])
        let future = DisplayFactsBuilder.facts(for: unknown, registry: registry)
        #expect(future.panelClass == .appleXDRExternal && future.sdrMaxNits == nil)
        // Without attributes (keys renamed, or not paired yet) the product still gives the class and the peak.
        let bare = DisplayFactsBuilder.facts(for: RawDisplayFixtures.proDisplay,
                                             registry: IORegistryFacts(builtIn: RawDisplayFixtures.ownerBuiltInPanel))
        #expect(bare.panelClass == .appleXDRExternal && bare.panelPeakNits == 1600 && bare.sdrMaxNits == 500)
        // The MSI and the built-in are untouched by the table.
        #expect(DisplayFactsBuilder.facts(for: RawDisplayFixtures.msi(), registry: registry).sdrMaxNits == nil)
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
