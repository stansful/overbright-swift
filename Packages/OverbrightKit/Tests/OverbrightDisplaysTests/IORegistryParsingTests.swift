// OverbrightDisplaysTests/IORegistryParsingTests.swift — IORegistry facts from the owner's saved values parse exactly
// (ARCHITECTURE.md §10.4 acceptance: MSI 465.49 / 265.05 / 0.0003 nits, PQ yes, HLG no; built-in potential 16, SDR
// max 600), every key is optional, and an external display is matched to its attributes by EDID IDs (§9.2 rule 6).
import Foundation
import Testing
@testable import OverbrightDisplays

@Suite struct IORegistryParsingTests {
    // MARK: The owner's values

    @Test func msiDisplayAttributesParseExactly() throws {
        let msi = try #require(ExternalPanelFacts.parse(displayAttributes: OwnerIORegistry.msiDisplayAttributes))
        #expect(msi.maxNits == 30_506_349.0 / 65536)
        #expect(msi.frameAverageNits == 17_370_142.0 / 65536)
        #expect(msi.minNits == 18.0 / 65536)
        #expect(try rounded(#require(msi.maxNits), 2) == 465.49)
        #expect(try rounded(#require(msi.frameAverageNits), 2) == 265.05)
        #expect(try rounded(#require(msi.minNits), 4) == 0.0003)
        #expect(msi.supportsPQ == true)
        #expect(msi.supportsHLG == false)
        #expect(msi.vendorID == 13929 && msi.vendorID == 0x3669)      // EDID PNP "MSI" = CGDisplayVendorNumber
        #expect(msi.productID == 19922)
        #expect(msi.serialNumber == 16_843_009)
        #expect(msi.productName == "MPG322UX OLED")
    }

    @Test func builtInBacklightParsesExactly() throws {
        let panel = try #require(BuiltInPanelFacts.parse(backlight: OwnerIORegistry.builtInBacklight,
                                                         displayParameters: OwnerIORegistry.builtInDisplayParameters))
        #expect(panel.potentialHeadroom == 16.0)
        #expect(panel.sdrMaxNits == 600.0)
        #expect(panel.panelPeakNits == 1600.0)                        // EDRPotentialHeadroom × 100
        #expect(panel.backlightMaxMilliNits == 1_599_999)
        #expect(panel.backlightMilliNits == 381_794)
    }

    @Test func deviceTreeDataIsLittleEndian() {
        #expect(IORegistryValue.fixedPointData(Data([0x00, 0x00, 0x10, 0x00])) == 16.0)
        #expect(IORegistryValue.fixedPointData(Data([0x00, 0x00, 0x58, 0x02])) == 600.0)
        #expect(IORegistryValue.fixedPointData(Data([0x00, 0x80, 0x01, 0x00])) == 1.5)
        #expect(IORegistryValue.floatData(OwnerIORegistry.builtInBacklight["aurora-maximum-nits"]) == 1000.0)
    }

    // MARK: Everything is optional

    @Test func missingOrMalformedValuesAreNil() {
        #expect(IORegistryValue.fixedPointData(Data([0x00, 0x10, 0x00])) == nil)          // 3 bytes
        #expect(IORegistryValue.fixedPointData(NSNumber(value: 16)) == nil)               // not data
        #expect(IORegistryValue.fixedPointInteger("30506349") == nil)                     // a string
        #expect(IORegistryValue.integer(kCFBooleanTrue) == nil)                           // a boolean is no integer
        #expect(IORegistryValue.uint32(NSNumber(value: -1)) == nil)
        #expect(IORegistryValue.uint32(NSNumber(value: Int64(UInt32.max) + 1)) == nil)
        #expect(IORegistryValue.bool(kCFBooleanFalse) == false)
        #expect(IORegistryValue.bool("Yes") == nil)
    }

    @Test func builtInFactsNeedAKnownKey() throws {
        #expect(BuiltInPanelFacts.parse(backlight: nil, displayParameters: nil) == nil)
        #expect(BuiltInPanelFacts.parse(backlight: ["name": Data("backlight".utf8)], displayParameters: [:]) == nil)
        // Without EDRPotentialHeadroom the backlight's maximum is kept for diagnostics but never taken as the panel
        // peak (undocumented; a value below the true peak would loosen Safe, C-PLATFORM-5).
        let lcd = try #require(BuiltInPanelFacts.parse(
            backlight: nil, displayParameters: ["BrightnessMilliNits": ["max": NSNumber(value: 500_000)]]))
        #expect(lcd.potentialHeadroom == nil && lcd.backlightMaxMilliNits == 500_000 && lcd.panelPeakNits == nil)
        let owner = try #require(RawDisplayFixtures.ownerBuiltInPanel)
        #expect(owner.panelPeakNits == 1600 && owner.backlightMaxMilliNits == 1_599_999)        // not 1599.999
        // Zero or garbage values are dropped, not reported as a 0-nit panel.
        let zero = BuiltInPanelFacts.parse(backlight: ["EDRPotentialHeadroom": Data([0, 0, 0, 0])], displayParameters: nil)
        #expect(zero == nil)
    }

    @Test func externalFactsNeedAProduct() throws {
        #expect(ExternalPanelFacts.parse(displayAttributes: [:]) == nil)
        #expect(ExternalPanelFacts.parse(displayAttributes: ["Luminance": ["Max": NSNumber(value: 30_506_349)]]) == nil)
        var attributes = OwnerIORegistry.msiDisplayAttributes
        attributes["Luminance"] = nil
        attributes["SupportsPQEOTF"] = nil
        let bare = try #require(ExternalPanelFacts.parse(displayAttributes: attributes))
        #expect(bare.maxNits == nil && bare.frameAverageNits == nil && bare.minNits == nil && bare.supportsPQ == nil)
        #expect(bare.vendorID == 13929)
        var unnamed = OwnerIORegistry.msiDisplayAttributes
        unnamed["ProductAttributes"] = ["LegacyManufacturerID": NSNumber(value: 13929), "ProductName": ""]
        #expect(try #require(ExternalPanelFacts.parse(displayAttributes: unnamed)).productName == nil)
    }

    // MARK: Matching an external display to its attributes

    @Test func externalMatchesByVendorProductThenSerial() {
        let left = ExternalPanelFacts(vendorID: 13929, productID: 19922, serialNumber: 1, maxNits: 465)
        let right = ExternalPanelFacts(vendorID: 13929, productID: 19922, serialNumber: 2, maxNits: 466)
        let other = ExternalPanelFacts(vendorID: 0x610, productID: 0xAE2F, serialNumber: 2, maxNits: 1600)
        let registry = IORegistryFacts(externals: [left, right, other], hasFramebufferServices: true)
        #expect(registry.external(vendor: 13929, product: 19922, serial: 2) == right)
        #expect(registry.external(vendor: 13929, product: 19922, serial: 1) == left)
        #expect(registry.external(vendor: 13929, product: 19922, serial: 99) == left)   // identical models: the first
        #expect(registry.external(vendor: 0x610, product: 0xAE2F, serial: 0) == other)  // the only match, any serial
        #expect(registry.external(vendor: 13929, product: 1, serial: 1) == nil)
        #expect(IORegistryFacts.unknown.external(vendor: 13929, product: 19922, serial: 1) == nil)
    }

    @Test func ownerRegistryMatchesTheMSIsCoreGraphicsIDs() throws {
        let registry = RawDisplayFixtures.ownerRegistry()
        let raw = RawDisplayFixtures.msi()
        let match = try #require(registry.external(vendor: raw.vendor, product: raw.model, serial: raw.serial))
        #expect(match.productName == "MPG322UX OLED")
    }

    private func rounded(_ value: Double, _ places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (value * scale).rounded() / scale
    }
}
