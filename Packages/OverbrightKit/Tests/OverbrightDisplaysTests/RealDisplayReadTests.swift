// OverbrightDisplaysTests/RealDisplayReadTests.swift — the real display ports, READ-ONLY, on the owner's Mac only
// (ARCHITECTURE.md §9.1 "OVERBRIGHT_HARDWARE (read-only real ports, owner only, never CI)", §10.4, D24). Off unless
// OVERBRIGHT_HARDWARE=1. Nothing here writes a table, restores, requests headroom or opens a window: the real
// `GammaPort` runs the shared read contract (the real-port variant of `GammaPortContractTests`) and its write counter
// must stay 0; the directory, registry, headroom and monitor only read (lint `noWritesInHardwareTests`).
import CoreGraphics
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite(.enabled(if: ProcessInfo.processInfo.environment["OVERBRIGHT_HARDWARE"] == "1",
                "reads the real displays (read-only): set OVERBRIGHT_HARDWARE=1"))
struct RealDisplayReadTests {
    private let absentDisplay: CGDirectDisplayID = 0x0BAD_F00D

    @Test func theGammaPortReadsAndNeverCountsAWrite() throws {
        let gamma = CoreGraphicsGamma()
        for id in CoreGraphicsDisplayReader.onlineIDs() where gamma.capacity(of: id) > 0 {
            try GammaPortReadContract.checkReadable(gamma, display: id)
            _ = gamma.profileHasVCGT(of: id)
        }
        GammaPortReadContract.checkAbsent(gamma, display: absentDisplay)
        #expect(gamma.writeCount == 0)
    }

    @Test func keysAreStableAndUnknownIDsHaveNone() {
        for id in CoreGraphicsDisplayReader.onlineIDs() {
            let key = DisplayKey.of(id)
            #expect(key != nil)
            #expect(DisplayKey.of(id) == key)
            #expect(key?.rawValue == key?.rawValue.uppercased())
        }
        #expect(DisplayKey.of(absentDisplay) == nil)
    }

    @Test func theSnapshotListsBuiltInFirstWithUniqueKeys() {
        let displays = SystemDisplayDirectory.onlineDisplays()
        #expect(Set(displays.map(\.ref.key)).count == displays.count)
        if let builtIn = displays.firstIndex(where: \.isBuiltIn) { #expect(builtIn == 0) }
        for facts in displays where facts.panelClass != .virtualDisplay {
            #expect(facts.gammaCapacity > 0, "\(facts.ref.key)")
        }
    }

    @Test func theRegistryReadIsPlausible() {
        let registry = IORegistryReader.read()
        if let potential = registry.builtIn?.potentialHeadroom { #expect(potential >= 1) }
        if let sdrMax = registry.builtIn?.sdrMaxNits { #expect(sdrMax > 100) }
        for external in registry.externals {
            if let maxNits = external.maxNits { #expect(maxNits > 0) }
            #expect(external.vendorID != nil || external.productID != nil)
        }
        #expect(registry.attributedExternalCount >= registry.externals.count)
        #if arch(arm64)
        // A walk that silently found nothing would pass every check above: on Apple silicon it must find the
        // framebuffer services, and the built-in's panel whenever the built-in is online (lid open).
        #expect(registry.hasFramebufferServices, "the IOKit walk found no IOMobileFramebufferShim")
        if CoreGraphicsDisplayReader.onlineIDs().contains(where: { CGDisplayIsBuiltin($0) != 0 }) {
            #expect(registry.builtIn != nil, "the built-in is online, but its backlight keys were not read")
        }
        #endif
    }

    /// Every real external display is paired with its IORegistry attributes and is not taken for a virtual one
    /// (the "no framebuffer service" rule must never catch a real monitor, C-PLATFORM-4). Apple silicon only: an
    /// Intel Mac has no `IOMobileFramebufferShim`.
    @Test func everyOnlineExternalIsPairedWithItsAttributes() {
        #if arch(arm64)
        let registry = IORegistryReader.read()
        let raw = CoreGraphicsDisplayReader.onlineDisplays(gamma: CoreGraphicsGamma())
        let facts = DisplayFactsBuilder.facts(from: raw, registry: registry)
        for display in raw where !display.isBuiltIn && display.vendor != DisplayFactsBuilder.placeholderVendor {
            let match = registry.external(vendor: display.vendor, product: display.model, serial: display.serial)
            #expect(match != nil, "no DisplayAttributes describe \(display.key)")
            #expect(facts.first { $0.ref.key == display.key }?.panelClass != .virtualDisplay, "\(display.key)")
        }
        #endif
    }

    @Test func headroomReadingsBelongToTheirDisplay() {
        let port = SystemHeadroomPort(time: SystemTimeSource())
        for facts in SystemDisplayDirectory.onlineDisplays() {
            let reading = port.reading(for: facts.ref)
            if facts.isMirrored { #expect(reading == nil) }
            if let reading {
                #expect(reading.display == facts.ref.id)
                #expect(reading.potential >= 0 && reading.current >= 0)
            }
        }
    }

    @Test func theDirectoryServiceStartsAndStops() async {
        let directory = SystemDisplayDirectory()
        var events: [SystemEvent] = []
        let token = directory.addEventObserver { events.append($0) }
        await directory.start()
        #expect(directory.displays == SystemDisplayDirectory.onlineDisplays())
        directory.stopNow()
        token.cancel()
        #expect(events.allSatisfy { if case .displayRemoved = $0 { false } else { true } })
    }

    @Test func theMonitorReadsTheRealDisplays() async {
        let time = SystemTimeSource()
        let gamma = CoreGraphicsGamma()
        var lines: [String] = []
        await DisplayMonitor.run(gamma: gamma, headroom: SystemHeadroomPort(time: time), time: time,
                                 interval: .milliseconds(250), duration: .milliseconds(600),
                                 displays: { CoreGraphicsDisplayReader.onlineIDs().compactMap { id in
                                     DisplayKey.of(id).map { DisplayRef(key: $0, id: id) } } },
                                 output: { lines.append($0) })
        let online = CoreGraphicsDisplayReader.onlineIDs().count
        #expect(online == 0 || (lines.count >= online && lines.count % online == 0))
        #expect(lines.allSatisfy { (try? JSONSerialization.jsonObject(with: Data($0.utf8))) != nil })
        #expect(gamma.writeCount == 0)
    }
}
