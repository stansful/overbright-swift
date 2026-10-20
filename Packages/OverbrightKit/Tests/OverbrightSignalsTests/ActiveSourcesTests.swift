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
        harness.settings[AutomationSettings.pauseForListedApps] = true                // off by default (2026-10-20)
        harness.settings[AutomationSettings.pausedApps] = [PausedAppRule(bundleID: "com.example.player", mode: .whilePlaying)]
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources.contains(.fullScreenWatch))
        harness.settings[AutomationSettings.pausedApps] = [PausedAppRule(bundleID: "com.example.photos", mode: .whileFrontmost)]
        await harness.settle()
        #expect(!harness.monitor.activeSources.contains(.fullScreenWatch))
    }

    /// The watch re-checks every 2 s on the shared grid (D29; `WatchGridTests` pins the phase): boosting at 1 s, the
    /// first tick comes at 2 s, then every 2 s, and none after the boost ends.
    @Test func theWatchRechecksEveryTwoSecondsWhileBoosting() async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        await harness.advance(.seconds(1))
        let reads = harness.platform.windowReads
        harness.monitor.setBoostActive(true)
        await harness.advance(.milliseconds(800))                             // the boost-on request (0.6 s)
        #expect(harness.platform.windowReads == reads + 1)
        await harness.advance(.milliseconds(200))                             // the first tick, at the grid point 2 s
        #expect(harness.platform.windowReads == reads + 2)
        await harness.advance(.milliseconds(4500))                            // ticks at 4 s and 6 s
        #expect(harness.platform.windowReads == reads + 4)
        harness.monitor.setBoostActive(false)
        await harness.advance(.seconds(10))
        #expect(harness.platform.windowReads == reads + 4)
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
        let harness = SignalsHarness(fixture: .mpg322uxHDROn, fullScreenVideoRule: true)
        harness.settings[FillLightSettings.autoWithCamera] = true
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        harness.platform.power = PowerState(source: .battery, batteryPercent: 50, isLowPowerMode: false)
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources == Set(SignalSource.allCases))
        await harness.monitor.stop()
        #expect(harness.monitor.activeSources.isEmpty)
        #expect(harness.platform.switchSources == 0 && harness.platform.batterySources == 0)
        #expect(harness.platform.cameraDevices.activeListeners == 0 && harness.platform.runningListObservers == 0)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
    }

    // MARK: Shielded (nobody sees the screen; the engine holds every display neutral)

    @Test func anIdlePauseStopsPollingWhileTheScreensSleepAndKeepsItsFlag() async {
        let harness = SignalsHarness(fixture: .mpg322uxHDROn)
        harness.platform.idleSeconds = 4000
        await harness.start()
        await harness.advance(.seconds(1))                                    // the launch full-screen check settles
        harness.monitor.setBoostActive(true)
        harness.monitor.setBoostActive(false)                                 // the idle pause made the OLED neutral
        #expect(harness.monitor.activeSources == alwaysOn.union([.idleDeadline]))
        let center = harness.platform.workspaceCenter
        harness.platform.post(NSWorkspace.screensDidSleepNotification, in: center)
        #expect(harness.monitor.activeSources == alwaysOn)
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)              // the pause holds
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)                               // no sleeper all night
        let reads = harness.platform.idleReads
        await harness.advance(.seconds(3600))
        #expect(harness.platform.idleReads == reads)
        // The screens wake by themselves: still idle, the 2 s poll resumes.
        harness.platform.post(NSWorkspace.screensDidWakeNotification, in: center)
        #expect(harness.platform.idleReads == reads + 1)
        #expect(harness.monitor.activeSources == alwaysOn.union([.idleDeadline]))
        #expect(harness.monitor.snapshot.isIdleBeyondThreshold)
        // A lock suspends it again; the user unlocks: the idle time is read, the pause ends, the poll stops.
        harness.platform.post(.init("com.apple.screenIsLocked"), in: harness.platform.distributedCenter)
        #expect(harness.monitor.activeSources == alwaysOn)
        harness.platform.idleSeconds = 1
        harness.platform.post(.init("com.apple.screenIsUnlocked"), in: harness.platform.distributedCenter)
        #expect(!harness.monitor.snapshot.isIdleBeyondThreshold)
        #expect(harness.monitor.activeSources == alwaysOn)
        await harness.advance(.seconds(1))
        #expect(harness.time.sleeperCount == 0)
    }

    /// One shield: the notification that raises it and the one that lowers it.
    enum Shield: String, CaseIterable, CustomTestStringConvertible {
        case lock, screensaver, displaySleep, systemSleep, otherSession

        var testDescription: String { rawValue }

        @MainActor func names(_ platform: FakeSignalsPlatform) -> (NotificationCenter, Notification.Name, Notification.Name) {
            switch self {
            case .lock: (platform.distributedCenter, .init("com.apple.screenIsLocked"), .init("com.apple.screenIsUnlocked"))
            case .screensaver:
                (platform.distributedCenter, .init("com.apple.screensaver.didstart"), .init("com.apple.screensaver.didstop"))
            case .displaySleep:
                (platform.workspaceCenter, NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification)
            case .systemSleep: (platform.workspaceCenter, NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification)
            case .otherSession:
                (platform.workspaceCenter, NSWorkspace.sessionDidResignActiveNotification,
                 NSWorkspace.sessionDidBecomeActiveNotification)
            }
        }
    }

    @Test(arguments: Shield.allCases)
    func aShieldStopsTheWatchAndTheBatteryPercentUntilItLifts(_ shield: Shield) async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        harness.platform.power = PowerState(source: .battery, batteryPercent: 80, isLowPowerMode: false)
        await harness.start()
        harness.monitor.setBoostActive(true)                                  // the engine kept the boost active
        let boosted = alwaysOn.union([.fullScreenWatch, .batteryPercent])
        #expect(harness.monitor.activeSources == boosted)
        let (center, begins, ends) = shield.names(harness.platform)
        center.post(name: begins, object: nil)
        #expect(harness.monitor.activeSources == alwaysOn)
        #expect(harness.platform.batterySources == 0)
        await harness.advance(.seconds(1))                                    // the boost-on request's one check
        let reads = harness.platform.windowReads
        await harness.advance(.seconds(30))
        #expect(harness.platform.windowReads == reads)                        // no 2 s re-check behind the shield
        #expect(harness.time.sleeperCount == 0)
        // The shield lifts: the percent is read before the sources resume; powerChanged follows the lift's event.
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.power = PowerState(source: .battery, batteryPercent: 61, isLowPowerMode: false)
        center.post(name: ends, object: nil)
        #expect(seen.last == .powerChanged && seen.count == 2)
        #expect(harness.monitor.snapshot.power.batteryPercent == 61)
        #expect(harness.monitor.activeSources == boosted)
        token.cancel()
    }

    @Test func overlappingShieldsResumeOnlyWhenTheLastOneLifts() async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources.contains(.fullScreenWatch))
        harness.platform.post(.init("com.apple.screenIsLocked"), in: harness.platform.distributedCenter)
        harness.platform.post(NSWorkspace.screensDidSleepNotification, in: harness.platform.workspaceCenter)
        harness.platform.post(.init("com.apple.screenIsUnlocked"), in: harness.platform.distributedCenter)
        #expect(!harness.monitor.activeSources.contains(.fullScreenWatch))   // the screens still sleep
        harness.platform.post(NSWorkspace.screensDidWakeNotification, in: harness.platform.workspaceCenter)
        #expect(harness.monitor.activeSources.contains(.fullScreenWatch))
    }

    @Test func aLaunchWhileLockedStartsNoShieldedSource() async {
        let harness = SignalsHarness()
        harness.platform.session = SessionState(isOnConsole: true, isScreenLocked: true)
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources == alwaysOn)
    }
}
