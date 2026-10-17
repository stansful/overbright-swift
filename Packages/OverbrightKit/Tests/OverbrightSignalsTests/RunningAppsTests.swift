// OverbrightSignalsTests/RunningAppsTests.swift — launches and terminations seen by the running list's KVO as well as
// the workspace notifications: agent and accessory apps (most boosters and gamma writers) post no did-launch or
// did-terminate notification on macOS 27.0.1, so the list is the only source that sees them. ARCHITECTURE.md §7.1,
// §7.2, §10.8. Synthetic IDs only (D3). No test observes the real workspace: the KVO plumbing runs over a scripted
// list of this test process's own `NSRunningApplication`.
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightSignals

/// A KVO-compliant list the tests change the way AppKit changes `runningApplications` (to-many insertions and
/// removals; a setting for the whole list). Nonisolated, so a test can change it on a background thread, where KVO
/// then notifies (`@unchecked Sendable`: every access to `storage` holds `lock`; changes come from one thread at a time).
nonisolated final class ScriptedRunningList: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [NSRunningApplication] = []
    /// The observed list.
    @objc var apps: [NSRunningApplication] { lock.withLock { storage } }

    func insert(_ app: NSRunningApplication) {
        let index = IndexSet(integer: apps.count)
        willChange(.insertion, valuesAt: index, forKey: "apps")
        lock.withLock { storage.append(app) }
        didChange(.insertion, valuesAt: index, forKey: "apps")
    }

    func removeAll() {
        let indexes = IndexSet(integersIn: 0..<apps.count)
        willChange(.removal, valuesAt: indexes, forKey: "apps")
        lock.withLock { storage.removeAll() }
        didChange(.removal, valuesAt: indexes, forKey: "apps")
    }

    func set(_ apps: [NSRunningApplication]) {
        willChangeValue(forKey: "apps")
        lock.withLock { storage = apps }
        didChangeValue(forKey: "apps")
    }
}

/// The changes a handler received (a class, so `@Sendable` main-actor closures can capture it).
@MainActor final class ChangeLog {
    var changes: [RunningAppsChange] = []
}

@MainActor @Suite struct RunningAppsTests {
    private let booster = RunningAppInfo(bundleID: "com.example.booster", processID: 201, localizedName: "Booster",
                                         isRegular: false)                // an LSUIElement booster
    private let tint = RunningAppInfo(bundleID: "com.example.tint", processID: 202, localizedName: "Tint")
    private let shade = RunningAppInfo(bundleID: "com.example.shade", processID: 203, isRegular: false)
    private let editor = RunningAppInfo(bundleID: "com.example.editor", processID: 204, localizedName: "Editor")

    // MARK: The KVO change

    @Test func eachKindOfChangeNamesWhoJoinedAndWhoLeft() {
        #expect(RunningAppsChange.make(kind: .insertion, old: nil, new: [booster])
                    == RunningAppsChange(added: [booster], removed: []))
        #expect(RunningAppsChange.make(kind: .removal, old: [tint], new: nil) == RunningAppsChange(added: [], removed: [tint]))
        // A setting and a replacement are compared by process ID: a process on both sides neither joined nor left.
        #expect(RunningAppsChange.make(kind: .setting, old: [tint, shade], new: [shade, editor])
                    == RunningAppsChange(added: [editor], removed: [tint]))
        #expect(RunningAppsChange.make(kind: .replacement, old: [tint], new: [tint]).isEmpty)
        #expect(RunningAppsChange.make(kind: .setting, old: nil, new: nil).isEmpty)
    }

    @Test func theObserverReportsTheListsInsertionsRemovalsAndSettings() {
        let list = ScriptedRunningList()
        let log = ChangeLog()
        let token = RunningAppsObserver.observe(list, \.apps) { log.changes.append($0) }
        let me = NSRunningApplication.current
        let info = RunningAppInfo(me)
        list.insert(me)                                               // on the main thread: delivered at once
        #expect(log.changes == [RunningAppsChange(added: [info], removed: [])])
        list.removeAll()
        #expect(log.changes.last == RunningAppsChange(added: [], removed: [info]))
        list.set([me])
        #expect(log.changes.last == RunningAppsChange(added: [info], removed: []))
        list.set([me])                                                // the same process: nothing to report
        #expect(log.changes.count == 3)
        token.cancel()
        list.removeAll()
        #expect(log.changes.count == 3)
    }

    // MARK: The filter

    @Test func aLaunchIsPostedOnceAndATerminationUnlessItWasJustPosted() {
        var filter = AppEventFilter(running: [10])
        var answers: [Bool] = []
        answers.append(filter.shouldPostLaunch(10))                    // running at start: no
        answers.append(filter.shouldPostLaunch(11))                    // yes
        answers.append(filter.shouldPostLaunch(11))                    // the second report: no
        answers.append(filter.shouldPostTermination(11))               // yes
        answers.append(filter.shouldPostTermination(11))               // the second report: no
        answers.append(filter.shouldPostTermination(99))               // never seen: still yes
        answers.append(filter.shouldPostLaunch(11))                    // a reused process ID launches again: yes
        answers.append(filter.shouldPostTermination(11))               // and terminates again: yes
        #expect(answers == [false, true, false, true, false, true, true, true])
    }

    @Test func theTerminationHistoryIsBounded() {
        var filter = AppEventFilter()
        for pid in Int32(1)...Int32(100) { _ = filter.shouldPostTermination(pid) }
        #expect(filter.ended.count == AppEventFilter.terminationHistory)
        #expect(filter.ended.first == 100 - Int32(AppEventFilter.terminationHistory) + 1)
        #expect(filter.running.isEmpty)
    }

    // MARK: The monitor

    @Test func anAgentAppSeenOnlyInTheRunningListIsAConflictUntilItQuits() async {
        let harness = SignalsHarness()
        await harness.start()
        await harness.advance(.seconds(1))                            // the launch full-screen check ran
        #expect(harness.platform.runningListObservers == 1)
        var seen: [(SystemEvent, [String])] = []
        let token = harness.monitor.addEventObserver { event in
            seen.append((event, harness.monitor.snapshot.conflicts.map(\.entryID)))
        }
        // Launched after Overbright (both login items): no notification at all, only the list.
        harness.apps.apps = [booster]
        harness.platform.changeRunningList(added: [booster])
        #expect(harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-booster"])
        // It quits: the banner, its continuation and an attributed trip end with the termination event.
        harness.apps.apps = []
        harness.platform.changeRunningList(removed: [booster])
        #expect(harness.monitor.snapshot.conflicts.isEmpty)
        #expect(seen.map(\.0) == [.appLaunched(bundleID: "com.example.booster"),
                                  .appTerminated(bundleID: "com.example.booster", processID: 201)])
        #expect(seen.map(\.1) == [["test-booster"], []])               // the snapshot first, then the event
        #expect(!harness.monitor.fullScreen.isPending)                 // not a regular app: no full-screen re-check
        token.cancel()
    }

    /// Background-only processes (XPC services) come and go every few seconds and reach Signals only through the
    /// running list (C-SIGNALS-1). Each termination is still posted (any table writer's death resets every display, so
    /// the engine's drift check needs it), but only a regular app's termination re-checks full screen: another app's
    /// window counts only while that app is frontmost, and a frontmost app that quits is followed by an activation.
    @Test func onlyARegularAppsTerminationReChecksFullScreen() async {
        let harness = SignalsHarness()
        await harness.start()
        await harness.advance(.seconds(1))                            // the launch full-screen check ran
        #expect(!harness.monitor.fullScreen.isPending)
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        let service = RunningAppInfo(bundleID: "com.example.helper.xpc", processID: 301, isRegular: false)
        harness.platform.changeRunningList(added: [service])
        harness.platform.changeRunningList(removed: [service])
        #expect(seen == [.appLaunched(bundleID: "com.example.helper.xpc"),
                         .appTerminated(bundleID: "com.example.helper.xpc", processID: 301)])
        #expect(!harness.monitor.fullScreen.isPending)
        harness.platform.changeRunningList(added: [editor])
        #expect(!harness.monitor.fullScreen.isPending)                // a launch alone never re-checks
        harness.platform.changeRunningList(removed: [editor])
        #expect(seen.last == .appTerminated(bundleID: "com.example.editor", processID: 204))
        #expect(harness.monitor.fullScreen.isPending)
        token.cancel()
    }

    @Test func aRegularAppReportedByBothSourcesIsPostedOnceInEitherOrder() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        let center = harness.platform.workspaceCenter
        harness.platform.changeRunningList(added: [tint])              // the list first
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: tint)
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: editor)   // the notification first
        harness.platform.changeRunningList(added: [editor])
        harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center, app: tint)
        harness.platform.changeRunningList(removed: [tint])
        harness.platform.changeRunningList(removed: [editor])
        harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center, app: editor)
        #expect(seen == [.appLaunched(bundleID: "com.example.tint"), .appLaunched(bundleID: "com.example.editor"),
                         .appTerminated(bundleID: "com.example.tint", processID: 202),
                         .appTerminated(bundleID: "com.example.editor", processID: 204)])
        token.cancel()
    }

    @Test func appsRunningAtStartAreNoLaunchesButTheirTerminationsArePosted() async {
        let harness = SignalsHarness()
        harness.platform.running = [shade]
        harness.apps.apps = [shade]
        await harness.start()
        #expect(harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-shade"])
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: harness.platform.workspaceCenter, app: shade)
        harness.apps.apps = []
        harness.platform.changeRunningList(removed: [shade])
        #expect(seen == [.appTerminated(bundleID: "com.example.shade", processID: 203)])
        #expect(harness.monitor.snapshot.conflicts.isEmpty)
        token.cancel()
    }

    @Test func oneListChangeReReadsTheConflictsOnceForEveryApp() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        // The live list may lag the change: the reported apps count anyway.
        harness.platform.changeRunningList(added: [booster, tint])
        #expect(harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-booster", "test-tint"])
        #expect(harness.journal.snapshot().filter { $0.code == "conflicts.changed" }.count == 1)
        #expect(seen == [.appLaunched(bundleID: "com.example.booster"), .appLaunched(bundleID: "com.example.tint")])
        token.cancel()
    }

    /// A report matches only the processes it adds, each once whichever source reported it first; a termination
    /// matches nothing; no report re-reads the list.
    @Test func aReportMatchesOnlyTheAppsItAddsOnce() async {
        let counter = CountingMatcher()
        let harness = SignalsHarness(match: counter.match)
        harness.platform.running = [shade, editor]
        harness.apps.apps = [shade, editor]
        await harness.start()
        #expect(counter.asked.sorted() == [203, 204] && harness.apps.listReads == 1)    // the start's full scan
        let center = harness.platform.workspaceCenter
        harness.platform.changeRunningList(added: [booster])                            // the list first
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: booster)
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: tint)   // the notification first
        harness.platform.changeRunningList(added: [tint])
        #expect(counter.asked.suffix(2) == [201, 202] && counter.asked.count == 4)
        harness.platform.changeRunningList(removed: [booster, shade])
        harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center, app: tint)
        #expect(counter.asked.count == 4 && harness.apps.listReads == 1)
        #expect(harness.monitor.snapshot.conflicts.isEmpty)
        // A reused process ID is a new launch: matched again.
        harness.platform.changeRunningList(added: [RunningAppInfo(bundleID: "com.example.shade", processID: 201)])
        #expect(counter.asked.count == 5 && harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-shade"])
    }

    /// A launch the reports missed (the running list changed but nobody said so) is found by the next full scan: on
    /// every path into boosting, when the session becomes active, after a wake and on a report without an app. Until
    /// then a report about another app does not find it.
    @Test(arguments: ["boost", "session", "wake", "launch", "termination"]) func aFullScanFindsWhatTheReportsMissed(path: String)
        async {
        let harness = SignalsHarness()
        await harness.start()
        let center = harness.platform.workspaceCenter
        harness.apps.apps = [booster]                                                   // never reported
        harness.platform.changeRunningList(added: [editor])
        #expect(harness.monitor.snapshot.conflicts.isEmpty && harness.apps.listReads == 1)
        harness.monitor.setBoostActive(false)                                           // leaving the boost scans nothing
        #expect(harness.apps.listReads == 1)
        switch path {
        case "boost": harness.monitor.setBoostActive(true)
        case "session": harness.platform.post(NSWorkspace.sessionDidBecomeActiveNotification, in: center)
        case "wake": harness.platform.post(NSWorkspace.didWakeNotification, in: center)
        case "launch": harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center)
        default: harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center)
        }
        #expect(harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-booster"], "\(path)")
        #expect(harness.apps.listReads == 2, "\(path)")
    }

    @Test func stopEndsTheRunningListObservation() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.monitor.stopNow()
        #expect(harness.platform.runningListObservers == 0)
        harness.platform.changeRunningList(added: [booster])
        #expect(seen.isEmpty && harness.monitor.snapshot.conflicts.isEmpty)
        token.cancel()
    }
}
