// OverbrightSignalsTests/IdleSchedulerTests.swift — the OLED idle pause: one deadline, a 2 s input poll while idle,
// video keeps it awake, OLED-only and boost-only. ARCHITECTURE.md §7.1, §7.3, D10, D22.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct IdleSchedulerTests {
    private let fiveMinutes: Duration = .seconds(300)

    @Test func beforeTheThresholdItWaitsForTheRest() {
        let decision = IdleScheduler.evaluate(secondsSinceInput: 120, threshold: fiveMinutes, displayHeldAwake: false)
        #expect(!decision.isIdle)
        #expect(decision.nextCheck == .seconds(180) + IdleScheduler.margin)
    }

    @Test func pastTheThresholdItIsIdleAndPollsForInput() {
        let decision = IdleScheduler.evaluate(secondsSinceInput: 300, threshold: fiveMinutes, displayHeldAwake: false)
        #expect(decision == IdleScheduler.Decision(isIdle: true, nextCheck: .seconds(2)))
        #expect(IdleScheduler.evaluate(secondsSinceInput: 4000, threshold: fiveMinutes, displayHeldAwake: false).isIdle)
    }

    @Test func videoKeepingTheDisplayAwakeIsNeverIdle() {
        let decision = IdleScheduler.evaluate(secondsSinceInput: 4000, threshold: fiveMinutes, displayHeldAwake: true)
        #expect(decision == IdleScheduler.Decision(isIdle: false, nextCheck: fiveMinutes))
    }

    @Test func anUnreadableIdleTimeIsNotIdle() {
        #expect(!IdleScheduler.evaluate(secondsSinceInput: nil, threshold: fiveMinutes, displayHeldAwake: false).isIdle)
        #expect(!IdleScheduler.evaluate(secondsSinceInput: .nan, threshold: fiveMinutes, displayHeldAwake: false).isIdle)
        #expect(!IdleScheduler.evaluate(secondsSinceInput: -1, threshold: fiveMinutes, displayHeldAwake: false).isIdle)
    }

    @Test func thresholdsComeFromTheSettingInMinutes() {
        #expect(IdleScheduler.threshold(minutes: 5) == .seconds(300))
        #expect(IdleScheduler.threshold(minutes: 1) == .seconds(60))
        #expect(IdleScheduler.threshold(minutes: 0) == .seconds(60))
        #expect(IdleScheduler.threshold(minutes: 90) == .seconds(1800))
    }

    @Test func oledIsThePanelClassUnlessOverridden() {
        let msi = DisplayFixture.mpg322uxHDROn.displays.map(\.facts)
        let builtIn = DisplayFixture.builtinXDRLidOpen.displays.map(\.facts)
        #expect(OLEDPresence.anyOLED(msi, preferences: [:]))
        #expect(!OLEDPresence.anyOLED(builtIn, preferences: [:]))
        #expect(!OLEDPresence.anyOLED(msi, preferences: [DisplayFixture.Keys.mpg322ux: DisplayPreferences(oled: .notOLED)]))
        #expect(OLEDPresence.anyOLED(builtIn, preferences: [DisplayFixture.Keys.builtIn: DisplayPreferences(oled: .oled)]))
    }

    // MARK: In the monitor

    @MainActor @Test func oneDeadlineThenPollingUntilInputReturns() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        await harness.start()
        harness.platform.idleSeconds = 60
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources.contains(.idleDeadline))
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        let reads = harness.platform.idleReads
        harness.platform.idleSeconds = 300.05                                // nobody touches the Mac meanwhile
        await harness.advance(.seconds(239))
        #expect(harness.platform.idleReads == reads)                         // no polling before the deadline
        await harness.advance(.seconds(2))
        #expect(harness.platform.idleReads == reads + 1)
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
        await harness.advance(.seconds(2))                                    // idle: re-read every 2 s
        #expect(harness.platform.idleReads == reads + 2 && harness.monitor.snapshot.isIdleBeyondThreshold)
        harness.platform.idleSeconds = 0.4                                    // the pointer moved
        await harness.advance(.seconds(2))
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        await harness.advance(.seconds(10))
        #expect(harness.platform.idleReads == reads + 3)                     // back to one deadline
    }

    @MainActor @Test func videoHoldsTheDisplayAwake() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        await harness.start()
        harness.platform.idleSeconds = 4000
        harness.platform.holders = [5000]
        harness.monitor.setBoostActive(true)
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        harness.platform.holders = []                                         // the video ended
        await harness.advance(.seconds(300))
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
    }

    @MainActor @Test func noOLEDDisplayMeansNoIdleSource() async {
        let harness = SignalsHarness(fixture: .builtinXDRLidOpen)
        await harness.start()
        harness.platform.idleSeconds = 4000
        harness.monitor.setBoostActive(true)
        #expect(!harness.monitor.activeSources.contains(.idleDeadline))
        #expect(harness.platform.idleReads == 0 && !harness.monitor.snapshot.isIdleBeyondThreshold)
        // The user marks the built-in as OLED: the source starts.
        harness.settings[DisplaySettings.perDisplay] = [DisplayFixture.Keys.builtIn: DisplayPreferences(oled: .oled)]
        await harness.settle()
        #expect(harness.monitor.activeSources.contains(.idleDeadline))
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
    }

    @MainActor @Test func boostInactiveClearsIdleAndStopsReading() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        await harness.start()
        harness.platform.idleSeconds = 4000
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
        harness.monitor.setBoostActive(false)
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        let reads = harness.platform.idleReads
        await harness.advance(.seconds(600))
        #expect(harness.platform.idleReads == reads)
    }

    @MainActor @Test func aShorterThresholdAppliesAtOnce() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        await harness.start()
        harness.platform.idleSeconds = 90
        harness.monitor.setBoostActive(true)
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        harness.settings[AutomationSettings.oledIdleMinutes] = 1
        await harness.settle()
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
    }
}
