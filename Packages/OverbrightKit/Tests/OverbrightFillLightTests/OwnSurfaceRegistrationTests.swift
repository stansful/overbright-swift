// OverbrightFillLightTests/OwnSurfaceRegistrationTests.swift — the frame registers its display with OwnEDRSurfaces
// exactly while it asks for EDR headroom there (ARCHITECTURE.md §3.9, §7.6, §10.9, D6; DESIGN.md §11: "the engine
// counts it as range already in use").
import OverbrightCore
import Testing
@testable import OverbrightFillLight

private let builtIn = DisplayFixture.Keys.builtIn
private let msi = DisplayFixture.Keys.mpg322ux

@MainActor @Suite struct OwnSurfaceRegistrationTests {
    private func started(_ fixture: DisplayFixture = .builtinXDRLidOpen) async -> FillLightHarness {
        let harness = FillLightHarness(fixture: fixture)
        await harness.start()
        return harness
    }

    @Test func heldExactlyWhileTheFrameShowsOnADisplayWithExtraRange() async {
        let h = await started()
        #expect(!h.ownEDRSurfaces.isHeld(builtIn))
        h.controller.setOn(true, source: .panel)
        #expect(h.ownEDRSurfaces.displays == [builtIn: 1])
        #expect(h.style?.headroomRequest != nil)
        h.controller.setOn(false, source: .panel)
        #expect(h.ownEDRSurfaces.displays.isEmpty)
    }

    @Test func settingsChangesKeepOneHold() async {
        let h = await started()
        h.controller.setOn(true, source: .panel)
        h.settings[FillLightSettings.brightness] = 1
        h.settings[FillLightSettings.width] = 100
        await h.settle()
        #expect(h.ownEDRSurfaces.displays == [builtIn: 1])
    }

    @Test func notHeldOnADisplayWithoutExtraRange() async {
        let h = await started(.mpg322uxHDROff)   // macOS HDR off: potential 1.0
        h.controller.setOn(true, source: .panel)
        #expect(h.factory.current?.isShown == true)
        #expect(h.style?.headroomRequest == nil)
        #expect(!h.ownEDRSurfaces.isHeld(msi))
    }

    @Test func notHeldWhenTheSurfaceRendersSDROnly() async {
        let h = FillLightHarness()
        h.factory.rendering = .sdr
        await h.start()
        h.controller.setOn(true, source: .panel)
        #expect(h.style?.headroomRequest == nil)
        #expect(h.ownEDRSurfaces.displays.isEmpty)
    }

    @Test func holdMovesWithTheChosenDisplay() async {
        let h = await started(.russianNames)   // the built-in and the MSI with HDR on
        h.controller.setOn(true, source: .panel)
        #expect(h.ownEDRSurfaces.displays == [builtIn: 1])
        h.settings[FillLightSettings.display] = msi
        await h.settle()
        #expect(h.ownEDRSurfaces.displays == [msi: 1])
    }

    @Test func releasedAtOnceWhenTheDisplayIsRemoved() async {
        let h = await started()
        h.controller.setOn(true, source: .panel)
        h.signals.emit(.displayRemoved(1))
        #expect(h.ownEDRSurfaces.displays.isEmpty)     // before emit returned, not after a debounce
        #expect(h.factory.live.isEmpty)
    }

    @Test func releasedWhenTheWindowLeavesItsDisplay() async {
        let h = await started()
        h.controller.setOn(true, source: .panel)
        h.factory.current?.moveToScreen(77)
        #expect(h.ownEDRSurfaces.displays.isEmpty)
    }

    @Test func releasedOnStop() async {
        let h = await started()
        h.controller.setOn(true, source: .panel)
        h.controller.stopNow()
        #expect(h.ownEDRSurfaces.displays.isEmpty)
        #expect(h.factory.live.isEmpty)
    }

    @Test func noHoldWithoutASurface() async {
        let h = FillLightHarness()
        h.factory.refused = [1]
        await h.start()
        h.controller.setOn(true, source: .panel)
        #expect(h.controller.isOn)
        #expect(h.ownEDRSurfaces.displays.isEmpty)
    }

    @Test func anotherSurfaceOnTheSameDisplayKeepsItsOwnHold() async {
        // The Welcome card or the calibration window may hold the same display; releasing ours leaves theirs.
        let h = await started()
        let welcome = h.ownEDRSurfaces.hold(builtIn)
        h.controller.setOn(true, source: .panel)
        #expect(h.ownEDRSurfaces.displays == [builtIn: 2])
        h.controller.setOn(false, source: .panel)
        #expect(h.ownEDRSurfaces.displays == [builtIn: 1])
        welcome.cancel()
    }
}
