// OverbrightFillLightTests/FillLightControllerTests.swift — zero work while off, the chosen display and its fallbacks,
// the EDR value following headroom, live settings, display removal and screen changes, announcements and the journal
// (ARCHITECTURE.md §10.9, §7.1, §7.6, D22; DESIGN.md §7.7, §11, §12.9).
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightFillLight

private let builtIn = DisplayFixture.Keys.builtIn
private let msi = DisplayFixture.Keys.mpg322ux

@MainActor @Suite struct FillLightControllerTests {
    private func on(_ fixture: DisplayFixture = .builtinXDRLidOpen) async -> FillLightHarness {
        let harness = FillLightHarness(fixture: fixture)
        await harness.start()
        harness.controller.setOn(true, source: .panel)
        return harness
    }

    // MARK: Energy

    @Test func offMeansNoSurfaceNoReadsNoObserverNoTask() async {
        let h = FillLightHarness()
        h.settings[FillLightSettings.autoWithCamera] = true   // the rule armed, but no camera
        await h.start()
        h.settings[FillLightSettings.width] = 90
        h.signals.snapshot.fullScreenDisplays = [builtIn]
        h.signals.emit(.screenParametersChanged)
        await h.advance(.seconds(60))
        #expect(h.factory.made.isEmpty)
        #expect(h.headroom.readCount == 0)
        #expect(h.signals.observerCount == 0)
        #expect(h.time.sleeperCount == 0)
        #expect(h.factory.openWindowCount == 0)
    }

    @Test func steadyOnDoesNoPeriodicWork() async {
        let h = await on()
        await h.advance(.seconds(6))                    // the settle reads are over
        let reads = h.headroom.readCount
        let styles = h.factory.current?.styles.count
        await h.advance(.seconds(600))
        #expect(h.time.sleeperCount == 0)
        #expect(h.headroom.readCount == reads)
        #expect(h.factory.current?.styles.count == styles)
        #expect(reads == 1 + FillLightTiming.headroomSettleReads.count)
    }

    @Test func turningOffRemovesEverything() async {
        let h = await on()
        h.controller.setOn(false, source: .menu)
        #expect(h.factory.live.isEmpty)
        #expect(h.signals.observerCount == 0)
        await h.settle()
        #expect(h.time.sleeperCount == 0)
        #expect(h.controller.currentDisplay == nil && h.controller.currentStyle == nil)
    }

    @Test func stopRemovesEverythingAndIgnoresLaterChanges() async {
        let h = await on()
        await h.controller.stop()
        #expect(h.factory.live.isEmpty && h.signals.observerCount == 0)
        h.settings[FillLightSettings.width] = 100
        h.signals.emit(.screenParametersChanged)
        await h.advance(.seconds(10))
        #expect(h.factory.made.count == 1)
        #expect(h.time.sleeperCount == 0)
    }

    @Test func turnedOnBeforeStartShowsOnlyOnceStarted() async {
        let h = FillLightHarness()
        h.controller.setOn(true, source: .launch)
        #expect(h.controller.isOn && h.factory.made.isEmpty)
        await h.start()
        #expect(h.factory.current?.isShown == true)
    }

    // MARK: Style

    @Test func showsTheSettingsStyleOnTheBuiltInDisplay() async {
        let h = await on()
        #expect(h.controller.currentDisplay == builtIn)
        let style = h.style
        #expect(style?.width == 48)
        #expect(style?.color == ColorTemperature.linearSRGB(warmth: 0.4))
        #expect(style?.reachesTop == false)
        // Idle headroom 1.0 before macOS answers: SDR white × brightness; the request asks for 2 × 0.8 ÷ 0.97.
        #expect(style.map { abs($0.value - 0.8) < 1e-9 } == true)
        #expect(style?.headroomRequest.map { abs($0 - 1.65) < 1e-9 } == true)
    }

    @Test func valueFollowsTheGrantUpToTwiceWhite() async {
        let h = await on()
        h.headroom.setOverride(1.5, for: builtIn)
        await h.advance(.milliseconds(500))               // the first settle read
        #expect(h.style.map { abs($0.value - 1.16) < 1e-9 } == true)     // 0.8 × 0.97 × 1.5 = 1.164 → 1.16
        h.headroom.setOverride(16.0 / 6, for: builtIn)      // the M4 Max's full grant
        h.signals.emit(.screenParametersChanged)            // macOS posts it when headroom moves
        #expect(h.style.map { abs($0.value - 1.6) < 1e-9 } == true)      // 0.8 × min(2.59, 2)
        h.settings[FillLightSettings.brightness] = 1
        await h.settle()
        #expect(h.style.map { abs($0.value - 2.0) < 1e-9 } == true)
        #expect(h.style.map { $0.displayedColor.maximum <= 0.97 * 16 / 6 } == true)
    }

    @Test func valueNeverExceedsNinetySevenPercentOfTheGrant() async {
        let h = await on()
        for grant in stride(from: 1.0, through: 3.0, by: 0.037) {
            h.headroom.setOverride(grant, for: builtIn)
            h.signals.emit(.screenParametersChanged)
            let value = h.style?.value ?? .infinity
            #expect(value <= max(0.97 * grant, 0.8) + 1e-9, "grant \(grant): value \(value)")
        }
    }

    @Test func displayWithoutExtraRangeGetsSDRWhite() async {
        let h = await on(.mpg322uxHDROff)
        #expect(h.style?.headroomRequest == nil)
        #expect(h.style.map { abs($0.value - 0.8) < 1e-9 } == true)
        #expect(h.time.sleeperCount == 0)                   // nothing to settle without a request
    }

    @Test func settingsChangeTheFrameLive() async {
        let h = await on()
        h.settings[FillLightSettings.width] = 80
        await h.settle()
        #expect(h.style?.width == 80)
        h.settings[FillLightSettings.warmth] = 1
        await h.settle()
        #expect(h.style?.color == ColorTemperature.linearSRGB(kelvin: 3_000))
        h.settings[FillLightSettings.brightness] = 1
        await h.settle()
        #expect(h.style?.headroomRequest.map { abs($0 - 2.07) < 1e-9 } == true)   // 2 ÷ 0.97 = 2.062, rounded up
        #expect(h.factory.made.count == 1)                  // changed in place, never a new window
    }

    @Test func fullScreenSpaceLetsTheFrameReachTheTop() async {
        let h = await on()
        h.signals.snapshot.fullScreenDisplays = [builtIn]
        await h.settle()
        #expect(h.style?.reachesTop == true)
        h.signals.snapshot.fullScreenDisplays = [msi]
        await h.settle()
        #expect(h.style?.reachesTop == false)
    }

    // MARK: Displays

    @Test func chosenDisplayElseTheBuiltIn() async {
        let h = await on(.russianNames)
        #expect(h.controller.currentDisplay == builtIn)
        h.settings[FillLightSettings.display] = msi
        await h.settle()
        #expect(h.controller.currentDisplay == msi)
        #expect(h.factory.made.count == 2 && h.factory.made[0].isRemoved)
        h.settings[FillLightSettings.display] = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000FF")
        await h.settle()
        #expect(h.controller.currentDisplay == builtIn)     // a display that is not connected: the default
    }

    @Test func withoutABuiltInTheMainDisplayElseTheFirst() async {
        let h = FillLightHarness(displays: [testDisplay(2), testDisplay(3)])
        h.mainDisplayID = 3
        await h.start()
        h.controller.setOn(true, source: .panel)
        #expect(h.factory.current?.display.id == 3)
        h.controller.setOn(false, source: .panel)
        h.mainDisplayID = 9                                  // the main display is not in the list
        h.controller.setOn(true, source: .panel)
        #expect(h.factory.current?.display.id == 2)
    }

    @Test func aMirrorMemberNeverHostsTheFrame() async {
        let h = FillLightHarness(fixture: .hardwareMirror)
        h.settings[FillLightSettings.display] = DisplayFixture.Keys.projector
        await h.start()
        h.controller.setOn(true, source: .panel)
        #expect(h.controller.currentDisplay == builtIn)
    }

    @Test func removedDisplayIsDroppedAtOnceThenTheLightFallsBack() async {
        let h = FillLightHarness(fixture: .russianNames)
        h.settings[FillLightSettings.display] = msi
        await h.start()
        h.controller.setOn(true, source: .panel)
        #expect(h.controller.currentDisplay == msi)
        h.signals.emit(.displayRemoved(2))
        #expect(h.factory.live.isEmpty)                      // when emit returns
        h.signals.emit(.screenParametersChanged)             // before the directory catches up: not back on it
        #expect(h.factory.current?.display.key != msi)
        h.directory.remove(msi)
        await h.settle()
        #expect(h.controller.currentDisplay == builtIn)
        #expect(h.controller.isOn)
        #expect(h.journalCodes.contains("fillLight.displayRemoved"))
    }

    @Test func aWindowMovedToAnotherScreenIsRemovedAndReplacedOnTheNextReconfiguration() async {
        let h = await on()
        h.factory.current?.moveToScreen(1)                   // the same display: nothing to do
        #expect(h.factory.live.count == 1)
        h.factory.current?.moveToScreen(42)
        #expect(h.factory.live.isEmpty && h.controller.isOn)
        #expect(h.journalCodes.contains("fillLight.leftDisplay"))
        h.signals.emit(.displaysReconfigured)
        #expect(h.factory.current?.display.key == builtIn)
        #expect(h.factory.made.count == 2)
    }

    @Test func wakeAndScreenChangesRefreshTheWindow() async {
        let h = await on()
        h.signals.emit(.didWake)
        h.signals.emit(.unlocked)
        h.signals.emit(.screenParametersChanged)
        #expect(h.factory.current?.refreshCount == 3)
        h.signals.emit(.appActivated(bundleID: nil))
        #expect(h.factory.current?.refreshCount == 3)
    }

    @Test func aDisplayThatCannotHostTheFrameIsJournaledOnce() async {
        let h = FillLightHarness()
        h.factory.refused = [1]
        await h.start()
        h.controller.setOn(true, source: .panel)
        h.signals.emit(.didWake)
        h.settings[FillLightSettings.width] = 60
        await h.settle()
        #expect(h.journalCodes.filter { $0 == "fillLight.surfaceFailed" }.count == 1)
        h.factory.refused = []
        h.signals.emit(.screenParametersChanged)
        #expect(h.factory.current?.isShown == true)
    }

    // MARK: Feedback

    @Test func announcesOnAndOff() async {
        let h = await on()
        h.controller.setOn(true, source: .shortcut)          // already on: nothing new
        h.controller.setOn(false, source: .shortcut)
        #expect(h.announcements.texts == ["Fill Light on", "Fill Light off"])
    }

    @Test func journalHoldsCodesNumbersAndKeysOnly() async {
        let h = await on()
        h.controller.setOn(false, source: .panel)
        let events = h.journal.snapshot()
        #expect(events.map(\.code) == ["fillLight.on", "fillLight.shown", "fillLight.off"])
        #expect(events.allSatisfy { $0.category == "fillLight" })
        let shown = events[1]
        #expect(shown.display == builtIn.rawValue)
        #expect(shown.values["rendering"] == FillLightRendering.taggedLayer.journalCode)
        #expect(shown.values["request"].map { abs($0 - 1.65) < 1e-9 } == true)
    }

    @Test func isObservable() async {
        let h = FillLightHarness()
        await h.start()
        var seen: [Bool] = []
        let token = observe({ h.controller.isOn }, onChange: { seen.append($0) })
        h.controller.setOn(true, source: .panel)
        await h.settle()
        h.controller.setOn(false, source: .panel)
        await h.settle()
        #expect(seen == [true, false])
        token.cancel()
    }
}
