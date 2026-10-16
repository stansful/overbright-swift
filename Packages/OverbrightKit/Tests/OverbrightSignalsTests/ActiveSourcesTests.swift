// OverbrightSignalsTests/ActiveSourcesTests.swift — the energy acceptance of §10.8: zero sources while the boost is
// inactive except the always-on cheap notifications, enumerated in every state, and checked against what really runs
// (sleeping tasks on the manual clock, IOKit sources and camera listeners registered with the fakes).
// ARCHITECTURE.md §7.1, §10.8, D22, DESIGN.md §17.
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightSignals

@MainActor @Suite struct ActiveSourcesTests {
    private let alwaysOn: Set<SignalSource> = [.workspaceNotifications, .distributedNotifications, .processNotifications,
                                              .powerSourceSwitch]

    @Test func theClassesAreDisjointAndComplete() {
        for source in SignalSource.allCases {
            #expect(!(source.isAlwaysOn && source.isBoostOnly), "\(source)")
        }
        #expect(Set(SignalSource.allCases.filter(\.isAlwaysOn)) == alwaysOn)
        #expect(Set(SignalSource.allCases.filter(\.isBoostOnly)) == [.batteryPercent, .idleDeadline, .fullScreenWatch,
                                                                      .scheduleBoundary])
    }

    @Test func constructingTouchesNothing() {
        let harness = SignalsHarness()
        #expect(harness.monitor.activeSources.isEmpty)
        #expect(harness.platform.powerReads == 0 && harness.platform.windowReads == 0 && harness.platform.switchSources == 0)
        #expect(harness.time.sleeperCount == 0)
    }

    @Test func offRunsOnlyTheAlwaysOnNotifications() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)                  // an OLED: the idle source would apply
        harness.platform.power = PowerState(source: .battery, batteryPercent: 50, isLowPowerMode: false)
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        await harness.start()
        await harness.advance(.seconds(1))                                    // the launch full-screen check settles
        #expect(harness.monitor.activeSources == alwaysOn)
        #expect(harness.time.sleeperCount == 0)                                // no timer, no task
        #expect(harness.platform.batterySources == 0 && harness.platform.switchSources == 1)
        // Events while off are handled on arrival and leave nothing running.
        harness.platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: harness.platform.workspaceCenter)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
        let reads = harness.platform.windowReads
        await harness.advance(.seconds(60))
        #expect(harness.platform.windowReads == reads && harness.platform.idleReads == 0)
    }

    @Test func boostingStartsEachBoostOnlySourceOnlyWhereItApplies() async {
        let harness = SignalsHarness(fixture: .builtinXDRLidOpen)
        await harness.start()
        harness.settings[AutomationSettings.pauseForFullScreenVideo] = false
        harness.settings[AutomationSettings.pauseForListedApps] = false
        await harness.settle()
        harness.monitor.setBoostActive(true)
        // Adapter, no OLED, no full-screen or player rule, no schedule: nothing extra.
        #expect(harness.monitor.activeSources == alwaysOn)
        harness.settings[AutomationSettings.pauseForFullScreenVideo] = true
        await harness.settle()
        #expect(harness.monitor.activeSources == alwaysOn.union([.fullScreenWatch]))
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        await harness.settle()
        #expect(harness.monitor.activeSources == alwaysOn.union([.fullScreenWatch, .scheduleBoundary]))
        harness.platform.switchPowerSource(to: PowerState(source: .battery, batteryPercent: 80, isLowPowerMode: false))
        #expect(harness.monitor.activeSources == alwaysOn.union([.fullScreenWatch, .scheduleBoundary, .batteryPercent]))
        #expect(harness.platform.batterySources == 1)
        harness.directory.add(DisplayFixture.mpg322uxHDROn.displays[0].facts)       // an OLED is plugged in
        await harness.settle()
        #expect(harness.monitor.activeSources == Set(SignalSource.allCases).subtracting([.camera]))
        #expect(harness.time.sleeperCount >= 3)                                // watch, idle and schedule really sleep

        harness.monitor.setBoostActive(false)
        #expect(harness.monitor.activeSources == alwaysOn)
        #expect(harness.platform.batterySources == 0)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
    }

    @Test func anIdlePauseInEffectIsTheOnlySourceThatOutlastsTheBoost() async {
        // The pause itself turns the boost off (§7.1: no display scaled); its input poll runs until the user is back.
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        harness.platform.power = PowerState(source: .battery, batteryPercent: 50, isLowPowerMode: false)
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        harness.platform.idleSeconds = 4000
        await harness.start()
        harness.monitor.setBoostActive(true)
        harness.monitor.setBoostActive(false)
        #expect(harness.monitor.activeSources == alwaysOn.union([.idleDeadline]))
        #expect(harness.platform.batterySources == 0)
        harness.platform.idleSeconds = 1
        await harness.advance(.seconds(2))
        #expect(harness.monitor.activeSources == alwaysOn)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
    }

    @Test func aPlayerRuleAloneKeepsTheWatch() async {
        let harness = SignalsHarness()
        harness.settings[AutomationSettings.pauseForFullScreenVideo] = false
        harness.settings[AutomationSettings.pausedApps] = [PausedAppRule(bundleID: "com.example.player", mode: .whilePlaying)]
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources.contains(.fullScreenWatch))
        harness.settings[AutomationSettings.pausedApps] = [PausedAppRule(bundleID: "com.example.photos", mode: .whileFrontmost)]
        await harness.settle()
        #expect(!harness.monitor.activeSources.contains(.fullScreenWatch))
    }

    @Test func theWatchRechecksEveryTwoSecondsWhileBoosting() async {
        let harness = SignalsHarness()
        await harness.start()
        await harness.advance(.seconds(1))
        let reads = harness.platform.windowReads
        harness.monitor.setBoostActive(true)
        await harness.advance(.seconds(1))                                    // the boost-on request (0.6 s)
        #expect(harness.platform.windowReads == reads + 1)
        await harness.advance(.milliseconds(4500))                            // ticks 2 s and 4 s after boosting
        #expect(harness.platform.windowReads == reads + 3)
        harness.monitor.setBoostActive(false)
        await harness.advance(.seconds(10))
        #expect(harness.platform.windowReads == reads + 3)
    }

    @Test func theCameraRuleIsTheOnlySourceIndependentOfTheBoost() async {
        let harness = SignalsHarness()
        harness.settings[FillLightSettings.autoWithCamera] = true
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.activeSources == alwaysOn.union([.camera]))
        #expect(harness.time.sleeperCount == 0)                                // listeners, not polling
    }

    @Test func stopEndsEverything() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        harness.settings[FillLightSettings.autoWithCamera] = true
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        harness.platform.power = PowerState(source: .battery, batteryPercent: 50, isLowPowerMode: false)
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources == Set(SignalSource.allCases))
        await harness.monitor.stop()
        #expect(harness.monitor.activeSources.isEmpty)
        #expect(harness.platform.switchSources == 0 && harness.platform.batterySources == 0)
        #expect(harness.platform.cameraDevices.activeListeners == 0)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
    }
}
