// OverbrightSignalsTests/SnapshotPublicationTests.swift — every notification updates the snapshot FIRST, then reaches
// every observer synchronously, in registration order (§4.1: a shield is neutral when the handler returns).
// ARCHITECTURE.md §3.3, §4.1, §7.1, §10.8.
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightSignals

@MainActor @Suite struct SnapshotPublicationTests {
    typealias F = WindowFixtures

    @Test func startReadsTheLaunchState() async {
        let harness = SignalsHarness()
        harness.platform.session = SessionState(isOnConsole: false, isScreenLocked: true)
        harness.platform.thermal = .serious
        harness.platform.power = PowerState(source: .battery, batteryPercent: 42, isLowPowerMode: true)
        harness.platform.reduceMotionValue = true
        harness.platform.hdrSuppressed = true
        harness.settings[EngineRecords.focusDirective] = .off
        await harness.start()
        let snapshot = harness.monitor.snapshot
        #expect(!snapshot.isSessionActive && snapshot.isScreenLocked && snapshot.isShielded)
        #expect(snapshot.thermal == .serious && snapshot.power == harness.platform.power)
        #expect(snapshot.reduceMotion && snapshot.isHDRSuppressed && snapshot.focus == .off)
        #expect(harness.journal.snapshot().contains { $0.code == "signals.started" && $0.values["onConsole"] == 0 })
    }

    @Test func everyStateNotificationUpdatesTheSnapshotBeforeItsEvent() async {
        let harness = SignalsHarness()
        await harness.start()
        let platform = harness.platform
        var seen: [(SystemEvent, SystemSnapshot)] = []
        let token = harness.monitor.addEventObserver { seen.append(($0, harness.monitor.snapshot)) }
        let cases: [(NotificationCenter, Notification.Name, SystemEvent, (SystemSnapshot) -> Bool)] = [
            (platform.distributedCenter, .init("com.apple.screenIsLocked"), .locked, { $0.isScreenLocked }),
            (platform.distributedCenter, .init("com.apple.screenIsUnlocked"), .unlocked, { !$0.isScreenLocked }),
            (platform.distributedCenter, .init("com.apple.screensaver.didstart"), .screensaverStarted, { $0.isScreensaverRunning }),
            (platform.distributedCenter, .init("com.apple.screensaver.didstop"), .screensaverStopped, { !$0.isScreensaverRunning }),
            (platform.workspaceCenter, NSWorkspace.willSleepNotification, .willSleep, { $0.isSystemSleeping }),
            (platform.workspaceCenter, NSWorkspace.didWakeNotification, .didWake, { !$0.isSystemSleeping }),
            (platform.workspaceCenter, NSWorkspace.screensDidSleepNotification, .screensDidSleep, { $0.areDisplaysAsleep }),
            (platform.workspaceCenter, NSWorkspace.screensDidWakeNotification, .screensDidWake, { !$0.areDisplaysAsleep }),
            (platform.workspaceCenter, NSWorkspace.sessionDidResignActiveNotification, .sessionResigned, { !$0.isSessionActive }),
            (platform.workspaceCenter, NSWorkspace.sessionDidBecomeActiveNotification, .sessionBecameActive, { $0.isSessionActive }),
        ]
        for (center, name, event, holds) in cases {
            let before = seen.count
            center.post(name: name, object: nil)
            #expect(seen.count == before + 1, "\(event) delivered before post returned")
            #expect(seen.last?.0 == event)
            #expect(seen.last.map { holds($0.1) } == true, "snapshot updated before \(event)")
            #expect(holds(harness.monitor.snapshot))
        }
        token.cancel()
    }

    @Test func shieldStatesComposeIntoIsShielded() async {
        let harness = SignalsHarness()
        await harness.start()
        harness.platform.post(.init("com.apple.screensaver.didstart"), in: harness.platform.distributedCenter)
        harness.platform.post(NSWorkspace.screensDidSleepNotification, in: harness.platform.workspaceCenter)
        #expect(harness.monitor.snapshot.isShielded)
        harness.platform.post(.init("com.apple.screensaver.didstop"), in: harness.platform.distributedCenter)
        #expect(harness.monitor.snapshot.isShielded)                       // the screens still sleep
        harness.platform.post(NSWorkspace.screensDidWakeNotification, in: harness.platform.workspaceCenter)
        #expect(!harness.monitor.snapshot.isShielded)
    }

    @Test func eventOnlyNotificationsPost() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.post(.init("com.apple.ColorSync.DisplayProfileNotification"), in: harness.platform.distributedCenter)
        harness.platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: harness.platform.workspaceCenter)
        harness.platform.reduceMotionValue = true
        harness.platform.post(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, in: harness.platform.workspaceCenter)
        harness.platform.post(NSWorkspace.didActivateApplicationNotification, in: harness.platform.workspaceCenter,
                              app: RunningAppInfo(bundleID: "com.example.editor", processID: 204))
        // Screen parameters belong to Displays: Signals only re-checks full screen, without an event.
        harness.platform.post(NSApplication.didChangeScreenParametersNotification, in: harness.platform.localCenter)
        #expect(seen == [.colorProfileChanged, .activeSpaceChanged, .accessibilityDisplayOptionsChanged,
                         .appActivated(bundleID: "com.example.editor")])
        #expect(harness.monitor.snapshot.reduceMotion)
        token.cancel()
    }

    @Test func hdrSuppressionIsPublishedAsAReason() async {
        guard #available(macOS 26.0, *) else { return }                     // the messages exist from macOS 26
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.post(NSApplication.ShouldBeginSuppressingHighDynamicRangeContent.name, in: harness.platform.localCenter)
        #expect(harness.monitor.snapshot.isHDRSuppressed && seen == [.hdrSuppressionBegan])
        harness.platform.post(NSApplication.ShouldEndSuppressingHighDynamicRangeContent.name, in: harness.platform.localCenter)
        #expect(!harness.monitor.snapshot.isHDRSuppressed && seen == [.hdrSuppressionBegan, .hdrSuppressionEnded])
        token.cancel()
    }

    @Test func observersRunInRegistrationOrderUntilTheirTokenEnds() async {
        let harness = SignalsHarness()
        await harness.start()
        var order: [String] = []
        let first = harness.monitor.addEventObserver { _ in order.append("first") }
        let second = harness.monitor.addEventObserver { _ in order.append("second") }
        harness.monitor.post(.displayRemoved(7))                            // Displays' events are forwarded the same way
        #expect(order == ["first", "second"])
        first.cancel()
        harness.monitor.post(.displayConfigurationBegan)
        #expect(order == ["first", "second", "second"])
        _ = second
    }

    @Test func theFullScreenCheckPublishesOneOutcomeAfterTheDebounce() async {
        let harness = SignalsHarness()
        let platform = harness.platform
        let movieURL = URL(fileURLWithPath: "/Applications/Player.app")
        let player = RunningAppInfo(bundleID: "com.example.player", processID: F.player, bundleURL: movieURL)
        await harness.start()
        await harness.advance(.seconds(1))                                   // the launch check ran: nothing
        #expect(platform.windowReads == 1 && harness.monitor.snapshot.frontmost == nil)
        platform.screenList = [F.builtIn, F.msi]
        platform.windows = WindowListSnapshot(windows: [F.menuBar(on: F.builtIn), F.window(F.player, 1728, 0, 2560, 1440)],
                                              windowServerPID: F.windowServer)
        platform.frontmost = player
        platform.running = [player]
        platform.holders = [F.player]
        platform.categories[movieURL] = "public.app-category.games"
        platform.post(NSWorkspace.didActivateApplicationNotification, in: platform.workspaceCenter, app: player)
        platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: platform.workspaceCenter)
        await harness.advance(.milliseconds(500))
        #expect(harness.monitor.snapshot.fullScreenDisplays.isEmpty)        // still debouncing
        await harness.advance(.milliseconds(100))
        #expect(platform.windowReads == 2)                                    // two requests, one check
        let snapshot = harness.monitor.snapshot
        #expect(snapshot.fullScreenDisplays == [DisplayFixture.Keys.mpg322ux])
        #expect(snapshot.fullScreenVideoDisplays == [DisplayFixture.Keys.mpg322ux])
        #expect(snapshot.frontmost == FrontmostApp(bundleID: "com.example.player", processID: F.player,
                                                   displays: [DisplayFixture.Keys.mpg322ux], isPlaying: true, isGame: true))
        #expect(harness.time.sleeperCount == 0)                              // nothing waits afterwards
    }

    @Test func anUnreadableAssertionListLeavesPlayingUnknown() async {
        let harness = SignalsHarness()
        harness.platform.frontmost = RunningAppInfo(bundleID: "com.example.player", processID: F.player)
        harness.platform.holders = nil
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.frontmost?.isPlaying == nil)
        #expect(harness.monitor.snapshot.frontmost?.isGame == false)
    }

    @Test func aStickyMenuBarIsReCheckedWhenItsMaskExpires() async {
        let harness = SignalsHarness()
        let platform = harness.platform
        platform.screenList = [F.builtIn]
        let tile = F.window(F.notes, 0, 32, 1728, 1085)                      // below the notch band
        platform.windows = WindowListSnapshot(windows: [tile], windowServerPID: F.windowServer)
        platform.frontmost = RunningAppInfo(bundleID: "com.example.notes", processID: F.notes)
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.fullScreenDisplays == [DisplayFixture.Keys.builtIn])
        // The pointer hovers at the top edge: the menu bar shows, the window stays.
        platform.windows = WindowListSnapshot(windows: [F.menuBar(on: F.builtIn), tile], windowServerPID: F.windowServer)
        platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: platform.workspaceCenter)
        await harness.advance(.milliseconds(600))
        #expect(harness.monitor.snapshot.fullScreenDisplays == [DisplayFixture.Keys.builtIn])   // sticky
        let reads = platform.windowReads
        await harness.advance(.seconds(3))                                   // the mask expires: one more check
        #expect(platform.windowReads == reads + 1)
        #expect(harness.monitor.snapshot.fullScreenDisplays.isEmpty)        // the menu bar stayed: a zoomed window
    }

    @Test func everyCheckReadsWhetherDisplaysHaveSeparateSpaces() async {
        // A player window exactly fills the MSI behind the editor; the MSI shows no menu bar.
        let harness = SignalsHarness()
        let platform = harness.platform
        platform.screenList = [F.builtIn, F.msi]
        platform.windows = WindowListSnapshot(windows: [F.menuBar(on: F.builtIn), F.window(F.editor, 100, 100, 800, 600),
                                                        F.window(F.player, 1728, 0, 2560, 1440)],
                                              windowServerPID: F.windowServer)
        platform.frontmost = RunningAppInfo(bundleID: "com.example.editor", processID: F.editor)
        platform.running = [RunningAppInfo(bundleID: "com.example.editor", processID: F.editor),
                            RunningAppInfo(bundleID: "com.example.player", processID: F.player)]
        platform.separateSpaces = false                                     // one menu bar, on the main display
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.fullScreenDisplays.isEmpty)
        platform.separateSpaces = true                                      // the MSI's missing menu bar now counts
        platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: platform.workspaceCenter)
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.fullScreenDisplays == [DisplayFixture.Keys.mpg322ux])
    }

    @Test func aFrontmostAppFullScreenOnANotchedSecondaryBuiltInIsPublished() async {
        // Spaces span the displays and the MSI is the main one: the built-in has no menu bar of its own, so the
        // tracker hands that to the detector and the frontmost app's window below the notch band counts (C-SIGNALS-5).
        let harness = SignalsHarness()
        let platform = harness.platform
        platform.screenList = [F.msiAlone, F.builtInSecondary]
        platform.windows = WindowListSnapshot(windows: [F.menuBar(on: F.msiAlone), F.window(F.notes, -1728, 355, 1728, 1085)],
                                              windowServerPID: F.windowServer)
        platform.frontmost = RunningAppInfo(bundleID: "com.example.notes", processID: F.notes)
        platform.running = [RunningAppInfo(bundleID: "com.example.notes", processID: F.notes)]
        platform.separateSpaces = false
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.fullScreenDisplays == [DisplayFixture.Keys.builtIn])
    }

    @Test func theFocusDirectiveIsPersistedAndPublished() async {
        let harness = SignalsHarness()
        await harness.start()
        let directive = FocusDirective.on(level: LevelPreset.sunlight.position)
        harness.monitor.setFocusDirective(directive)
        #expect(harness.monitor.snapshot.focus == directive)
        // The next launch reads it back before anything else runs.
        let relaunched = SignalsMonitor(settings: SettingsStore(defaults: harness.defaults), time: harness.time,
                                        journal: harness.journal, displays: harness.directory,
                                        platform: FakeSignalsPlatform(), conflicts: nil, calendar: harness.calendar)
        await relaunched.start()
        #expect(relaunched.snapshot.focus == directive)
        harness.monitor.setFocusDirective(.leaveAlone)
        #expect(SettingsStore(defaults: harness.defaults).isDefault(EngineRecords.focusDirective))
        relaunched.stopNow()
    }

    @Test func aDirectiveBeforeStartSurvivesTheStart() async {
        let harness = SignalsHarness()
        harness.monitor.setFocusDirective(.off)                              // the launch-time Focus filter read
        await harness.start()
        #expect(harness.monitor.snapshot.focus == .off)
    }

    @Test func stopRemovesEveryObserver() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.monitor.stopNow()
        harness.platform.post(.init("com.apple.screenIsLocked"), in: harness.platform.distributedCenter)
        harness.platform.post(NSWorkspace.willSleepNotification, in: harness.platform.workspaceCenter)
        harness.platform.thermal = .critical
        harness.platform.post(ProcessInfo.thermalStateDidChangeNotification, in: harness.platform.localCenter)
        await harness.settle()
        #expect(seen.isEmpty && !harness.monitor.snapshot.isScreenLocked && harness.monitor.snapshot.thermal == .nominal)
        #expect(harness.platform.switchSources == 0 && harness.monitor.activeSources.isEmpty)
        token.cancel()
    }

    @Test func theJournalHoldsCodesAndNumbersOnly() async {
        let harness = SignalsHarness()
        await harness.start()
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: harness.platform.workspaceCenter,
                              app: RunningAppInfo(bundleID: "com.example.booster", processID: 201, localizedName: "Booster"))
        harness.monitor.setBoostActive(true)
        let journal = harness.journal.snapshot()
        #expect(journal.contains { $0.code == "conflicts.changed" && $0.values["count"] == 1 })
        #expect(journal.contains { $0.code == "signals.boostActive" && $0.values["active"] == 1 })
        #expect(journal.allSatisfy { $0.category == "signals" && $0.display == nil })
        #expect(!journal.contains { $0.code.contains("Booster") || $0.code.contains("example") })
    }
}
