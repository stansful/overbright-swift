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

    @Test func eachVirtualRuleAloneMakesADisplayVirtual() {
        let msi = RawDisplayFixtures.msi()
        var noTable = msi
        noTable.gammaCapacity = 0
        var unreadable = msi
        unreadable.tableReadable = false
        var placeholder = msi
        placeholder.vendor = DisplayFactsBuilder.placeholderVendor
        var noFramebuffer = msi
        noFramebuffer.vendor = 0x1E6D                                 // no attributes describe it
        for raw in [noTable, unreadable, placeholder, noFramebuffer] {
            #expect(DisplayFactsBuilder.facts(for: raw, registry: registry).panelClass == .virtualDisplay, "\(raw)")
        }
        #expect(DisplayFactsBuilder.facts(for: msi, registry: registry).panelClass != .virtualDisplay)
    }

    @Test func aMissingFramebufferServiceCountsOnlyOnAppleSilicon() {
        var intel = RawDisplayFixtures.msi()
        intel.vendor = 0x1E6D
        let noServices = IORegistryFacts(builtIn: nil, externals: [], hasFramebufferServices: false)
        let facts = DisplayFactsBuilder.facts(for: intel, registry: noServices)
        #expect(facts.panelClass == .hdrExternal)                     // from NSScreen potential 4.65, PQ unknown
        #expect(facts.supportsPQ == nil && facts.panelPeakNits == nil)
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
