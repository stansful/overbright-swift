// OverbrightDisplaysTests/VirtualAndMirrorTests.swift — virtual displays, hardware-mirror members and the closed lid
// (ARCHITECTURE.md §3.2, §3.6, §10.4; D8): which displays are virtual (capacity 0, failed read, placeholder vendor, no
// framebuffer service), which are dim-only mirror members, that a mirror member has no headroom reading of its own,
// and that the built-in display leaves the list while the lid is closed. Pure builders and samplers; no display.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct VirtualAndMirrorTests {
    private let registry = RawDisplayFixtures.ownerRegistry()

    // MARK: Virtual displays

    @Test func sidecarIsVirtualLikeCoresFixture() throws {
        let facts = DisplayFactsBuilder.facts(from: [RawDisplayFixtures.builtIn(), RawDisplayFixtures.sidecar],
                                              registry: registry)
        let sidecar = try #require(facts.first { $0.ref.key == DisplayFixture.Keys.sidecar })
        let expected = try #require(DisplayFixture.sidecar.displays.first { $0.key == DisplayFixture.Keys.sidecar })
        #expect(sidecar.panelClass == .virtualDisplay)
        #expect(sidecar == expected.facts)
    }

    @Test func eachVirtualRuleAloneMakesADisplayVirtual() throws {
        let msi = RawDisplayFixtures.msi()
        var noTable = msi
        noTable.gammaCapacity = 0
        var unreadable = msi
        unreadable.tableReadable = false
        var placeholder = msi
        placeholder.vendor = DisplayFactsBuilder.placeholderVendor
        for raw in [noTable, unreadable, placeholder] {
            #expect(DisplayFactsBuilder.facts(for: raw, registry: registry).panelClass == .virtualDisplay, "\(raw)")
        }
        #expect(DisplayFactsBuilder.facts(for: msi, registry: registry).panelClass != .virtualDisplay)
        // No framebuffer: the MSI's attributes parse, and one framebuffer with attributes serves two external
        // displays, so the one nothing describes has none (a software display with a real-looking vendor).
        let facts = DisplayFactsBuilder.facts(from: [RawDisplayFixtures.builtIn(), msi, Self.unattributed],
                                              registry: RawDisplayFixtures.ownerRegistry(extra: []))
        #expect(try #require(facts.first { $0.ref.key == Self.unattributed.key }).panelClass == .virtualDisplay)
        #expect(try #require(facts.first { $0.ref.key == msi.key }).panelClass == .oledExternal)
    }

    /// An external display with a real-looking vendor that no `DisplayAttributes` describe.
    private static let unattributed = RawDisplay(
        id: 7, key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000007"), isBuiltIn: false, gammaCapacity: 1024,
        tableReadable: true, vendor: 0x1E6D, model: 0x5B8E, serial: 7, mirrorsDisplay: kCGNullDirectDisplay,
        screen: RawDisplay.Screen(name: "Display", potential: 1, hasNotch: false))

    /// The "no framebuffer" rule applies only on the walk's positive evidence (C-PLATFORM-4): a renamed or missing
    /// key, or attributes that have not arrived, never turn a real monitor into a virtual display (no boost, no dim).
    @Test func aMissingFramebufferNeedsTheWalksEvidence() throws {
        let online = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi()]
        func msiClass(_ registry: IORegistryFacts) throws -> PanelClass {
            let facts = DisplayFactsBuilder.facts(from: online, registry: registry)
            return try #require(facts.first { $0.ref.key == DisplayFixture.Keys.mpg322ux }).panelClass
        }
        let builtIn = RawDisplayFixtures.ownerBuiltInPanel
        // ProductAttributes renamed: the framebuffer carries attributes nothing can parse.
        var renamed = OwnerIORegistry.msiDisplayAttributes
        let attributes = renamed.removeValue(forKey: "ProductAttributes")
        renamed["ProductInfo"] = attributes
        #expect(ExternalPanelFacts.parse(displayAttributes: renamed) == nil)
        let unparsed = IORegistryFacts(builtIn: builtIn, attributedExternals: 1, hasFramebufferServices: true)
        #expect(try msiClass(unparsed) == .hdrExternal)                // NSScreen's potential 4.65, peak 465.49
        // LegacyManufacturerID renamed: the attributes parse but describe no CoreGraphics vendor.
        var noVendor = OwnerIORegistry.msiDisplayAttributes
        var product = try #require(noVendor["ProductAttributes"] as? [String: Any])
        let vendor = product.removeValue(forKey: "LegacyManufacturerID")
        product["ManufacturerIDLegacy"] = vendor
        noVendor["ProductAttributes"] = product
        let vendorless = try #require(ExternalPanelFacts.parse(displayAttributes: noVendor))
        #expect(vendorless.vendorID == nil)
        #expect(try msiClass(IORegistryFacts(builtIn: builtIn, externals: [vendorless],
                                             hasFramebufferServices: true)) != .virtualDisplay)
        // Attributes not there yet: framebuffer services exist, but no external has any.
        #expect(try msiClass(IORegistryFacts(builtIn: builtIn, hasFramebufferServices: true)) != .virtualDisplay)
        // A framebuffer per external display: nothing is missing, whatever the matching says.
        let both = IORegistryFacts(builtIn: builtIn, externals: [vendorless], attributedExternals: 2,
                                   hasFramebufferServices: true)
        let two = DisplayFactsBuilder.facts(from: online + [Self.unattributed], registry: both)
        #expect(two.allSatisfy { $0.panelClass != .virtualDisplay })
        // The owner's attributes as read: the MSI is paired and real.
        #expect(try msiClass(RawDisplayFixtures.ownerRegistry()) == .oledExternal)
    }

    @Test func aMissingFramebufferServiceCountsOnlyOnAppleSilicon() {
        var intel = RawDisplayFixtures.msi()
        intel.vendor = 0x1E6D
        let noServices = IORegistryFacts(builtIn: nil, externals: [], hasFramebufferServices: false)
        let facts = DisplayFactsBuilder.facts(for: intel, registry: noServices)
        #expect(facts.panelClass == .hdrExternal)                     // from NSScreen potential 4.65, PQ unknown
        #expect(facts.supportsPQ == nil)
        #expect(abs((facts.panelPeakNits ?? 0) - 465.49) < 1e-9)      // potential × 100 (D8), no IORegistry
        // A built-in display never needs an external framebuffer service.
        let builtIn = DisplayFactsBuilder.facts(for: RawDisplayFixtures.builtIn(),
                                                registry: IORegistryFacts(hasFramebufferServices: true))
        #expect(builtIn.panelClass == .builtInXDR)
    }

    // MARK: Hardware mirrors

    @Test func aMirrorMemberWithoutItsOwnScreenIsDimOnlyLikeCoresFixture() throws {
        let facts = DisplayFactsBuilder.facts(from: [RawDisplayFixtures.projector, RawDisplayFixtures.builtIn()],
                                              registry: registry)
        let projector = try #require(facts.first { $0.ref.key == DisplayFixture.Keys.projector })
        let expected = try #require(DisplayFixture.hardwareMirror.displays.first { $0.key == DisplayFixture.Keys.projector })
        #expect(projector.isMirrored)
        #expect(projector.gammaCapacity == 256 && projector.panelClass == .sdrExternal)
        #expect(projector.isMirrored == expected.facts.isMirrored && projector.panelClass == expected.facts.panelClass)
        #expect(projector.supportsPQ == expected.facts.supportsPQ)
        // No NSScreen of its own: the name comes from its framebuffer's product name (UI only).
        #expect(projector.name == "Projector")
        // The master of the set keeps its own screen and is not a member.
        #expect(facts.first { $0.isBuiltIn }?.isMirrored == false)
    }

    @Test func mirrorMembershipNeedsBothAMasterAndNoOwnScreen() {
        var withScreen = RawDisplayFixtures.projector
        withScreen.screen = RawDisplay.Screen(name: "Projector", potential: 1, hasNotch: false)
        #expect(!DisplayFactsBuilder.isMirrorMember(withScreen))
        var noMaster = RawDisplayFixtures.projector
        noMaster.mirrorsDisplay = kCGNullDirectDisplay
        #expect(!DisplayFactsBuilder.isMirrorMember(noMaster))         // a display in transition, not a mirror
        #expect(DisplayFactsBuilder.isMirrorMember(RawDisplayFixtures.projector))
    }

    @Test func aMirrorMemberHasNoHeadroomReading() {
        let ref = DisplayRef(key: DisplayFixture.Keys.projector, id: 6)
        let ownValues = ScreenEDRValues(display: 6, current: 1.2, potential: 4, reference: 0)
        let now = MonotonicInstant(sinceOrigin: .seconds(3))
        #expect(HeadroomSampler.reading(for: ref, screen: ownValues, mirrorsDisplay: 1, time: now) == nil)
        #expect(HeadroomSampler.reading(for: ref, screen: nil, mirrorsDisplay: kCGNullDirectDisplay, time: now) == nil)
        let master = ScreenEDRValues(display: 1, current: 2.6, potential: 16, reference: 0)
        #expect(HeadroomSampler.reading(for: ref, screen: master, mirrorsDisplay: kCGNullDirectDisplay, time: now) == nil)
    }

    @Test func aReadingIsStampedWithItsDisplayAndTime() throws {
        let ref = DisplayRef(key: DisplayFixture.Keys.builtIn, id: 1)
        let now = MonotonicInstant(sinceOrigin: .milliseconds(1250))
        let values = ScreenEDRValues(display: 1, current: 2.667, potential: 16, reference: 0)
        let reading = try #require(HeadroomSampler.reading(for: ref, screen: values, mirrorsDisplay: kCGNullDirectDisplay,
                                                           time: now))
        #expect(reading == HeadroomReading(display: 1, current: 2.667, potential: 16, reference: 0, time: now))
        for broken in [Double.nan, .infinity] {
            let bad = ScreenEDRValues(display: 1, current: broken, potential: 16, reference: 0)
            #expect(HeadroomSampler.reading(for: ref, screen: bad, mirrorsDisplay: kCGNullDirectDisplay, time: now) == nil)
        }
    }

    // MARK: Clamshell

    @Test func theBuiltInLeavesTheListWhileTheLidIsClosed() {
        let raw = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi()]
        let closed = DisplayFactsBuilder.facts(from: raw, registry: RawDisplayFixtures.ownerRegistry(lidClosed: true))
        #expect(closed.map(\.ref.key) == [DisplayFixture.Keys.mpg322ux])
        for lid in [false, nil] as [Bool?] {
            let open = DisplayFactsBuilder.facts(from: raw, registry: RawDisplayFixtures.ownerRegistry(lidClosed: lid))
            #expect(open.map(\.ref.key) == [DisplayFixture.Keys.builtIn, DisplayFixture.Keys.mpg322ux])
        }
    }
}
