// OverbrightSignalsTests/ConflictProbeTests.swift — running conflicts, scripted launches and terminations, team reads,
// and drift attribution with the libproc fallback. ARCHITECTURE.md §3.6, §7.2, §10.8. Synthetic IDs only (D3).
import AppKit
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightSignals

@MainActor @Suite struct ConflictProbeTests {
    private let booster = RunningAppInfo(bundleID: "com.example.booster", processID: 201, localizedName: "Booster")
    private let tint = RunningAppInfo(bundleID: "com.example.tint", processID: 202, localizedName: "Tint")
    private let shade = RunningAppInfo(bundleID: "com.example.shade", processID: 203, localizedName: "Shade")
    private let editor = RunningAppInfo(bundleID: "com.example.editor", processID: 204, localizedName: "Editor")
    private let ourselves = RunningAppInfo(bundleID: "app.overbright.Overbright", processID: 100, localizedName: "Overbright")
    private let dimmerURL = URL(fileURLWithPath: "/Applications/Dimmer.app", isDirectory: true)

    private func probe(_ apps: FakeRunningApps) -> RunningAppsConflictProbe {
        RunningAppsConflictProbe(catalog: TestCatalog.all, ownBundleID: "app.overbright.Overbright", source: apps,
                                 match: TestCatalog.match)
    }

    @Test func runningMatchesAreListedMostSevereFirstAndReadLive() {
        let apps = FakeRunningApps()
        let probe = probe(apps)
        #expect(probe.runningConflicts().isEmpty)
        apps.apps = [shade, editor, tint, booster, ourselves]
        // Read on every call: the launch rescue asks before Signals has started.
        #expect(probe.runningConflicts().map(\.entryID) == ["test-booster", "test-tint", "test-shade"])
        #expect(probe.runningConflicts().first?.displayName == "Booster")
        #expect(probe.runningConflicts().first?.bundleID == "com.example.booster")   // exact, case-insensitively
    }

    @Test func aBundleLessToolMatchesByExecutable() {
        let apps = FakeRunningApps()
        apps.apps = [RunningAppInfo(bundleID: nil, processID: 300, executableName: "example-boost", localizedName: "example-boost",
                                    isRegular: false)]
        #expect(probe(apps).runningConflicts().map(\.entryID) == ["test-tool"])
    }

    @Test func theTeamIsReadOnlyForCataloguedPrefixesAndOnlyOnce() {
        let apps = FakeRunningApps()
        let dimmer = RunningAppInfo(bundleID: "com.example.dimmer.pro", processID: 205, bundleURL: dimmerURL,
                                    localizedName: "Dimmer")
        let editorWithBundle = RunningAppInfo(bundleID: "com.example.editor", processID: 204,
                                              bundleURL: URL(fileURLWithPath: "/Applications/Editor.app"),
                                              localizedName: "Editor")
        apps.apps = [dimmer, editorWithBundle]
        let probe = probe(apps)
        #expect(probe.runningConflicts().isEmpty)                          // unsigned by the catalogued team
        apps.teams[dimmerURL] = "TEAM123456"
        #expect(probe.runningConflicts().isEmpty)                          // the first answer is cached per bundle
        #expect(apps.teamReads == [dimmerURL])                              // never read for the editor
        let fresh = self.probe(apps)
        #expect(fresh.runningConflicts().map(\.entryID) == ["test-dimmer"])
    }

    @Test func aSiblingOfTheSameVendorIsNotMatched() {
        let apps = FakeRunningApps()
        apps.apps = [RunningAppInfo(bundleID: "com.example.dimmerhelper", processID: 206,
                                    bundleURL: URL(fileURLWithPath: "/Applications/Helper.app"), localizedName: "Helper")]
        apps.teams[URL(fileURLWithPath: "/Applications/Helper.app")] = "OTHERTEAM1"
        #expect(probe(apps).runningConflicts().isEmpty)
    }

    @Test func scriptedLaunchesAndTerminationsReachTheSnapshotThenTheEvent() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [(SystemEvent, [String])] = []
        let token = harness.monitor.addEventObserver { event in
            seen.append((event, harness.monitor.snapshot.conflicts.map(\.entryID)))
        }
        // Launch: LaunchServices may not list the app yet when the notification arrives; it counts anyway.
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: harness.platform.workspaceCenter, app: booster)
        #expect(harness.monitor.snapshot.conflicts.map(\.entryID) == ["test-booster"])
        harness.apps.apps = [booster]
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: harness.platform.workspaceCenter, app: tint)
        harness.apps.apps = [booster, tint]
        // An ordinary app launching changes nothing but still posts its event.
        harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: harness.platform.workspaceCenter, app: editor)
        // Termination: the process may still be listed; it no longer counts.
        harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: harness.platform.workspaceCenter, app: booster)
        #expect(seen.map(\.0) == [.appLaunched(bundleID: "com.example.booster"), .appLaunched(bundleID: "com.example.tint"),
                                  .appLaunched(bundleID: "com.example.editor"),
                                  .appTerminated(bundleID: "com.example.booster", processID: 201)])
        // The snapshot is current when each event arrives.
        #expect(seen.map(\.1) == [["test-booster"], ["test-booster", "test-tint"], ["test-booster", "test-tint"],
                                  ["test-tint"]])
        token.cancel()
    }

    /// Without an injected matcher the probe matches with Policy's prepared catalogue: case, `-setapp` twins, team-confirmed
    /// prefixes and executables as §7.2 states them, and never Overbright itself.
    @Test func theLiveProbeMatchesWithThePreparedCatalogue() {
        let apps = FakeRunningApps()
        apps.apps = [shade, editor, ourselves,
                     RunningAppInfo(bundleID: "COM.EXAMPLE.booster-setapp", processID: 207, localizedName: "Booster"),
                     RunningAppInfo(bundleID: "com.example.Dimmer-Pro", processID: 205, bundleURL: dimmerURL, localizedName: "Dimmer"),
                     RunningAppInfo(bundleID: nil, processID: 300, executableName: "EXAMPLE-BOOST", isRegular: false)]
        apps.teams[dimmerURL] = "team123456"
        let probe = RunningAppsConflictProbe(catalog: TestCatalog.all, ownBundleID: "app.overbright.Overbright", source: apps)
        #expect(probe.runningConflicts().map(\.entryID) == ["test-booster", "test-tool", "test-dimmer", "test-shade"])
        #expect(probe.runningConflicts().map(\.processID) == [207, 300, 205, 203])
        #expect(apps.teamReads == [dimmerURL])                              // read once, only for the team-naming prefix
        let scan = probe.scan()
        #expect(scan.processIDs == [203, 204, 100, 207, 205, 300] && scan.conflicts == probe.runningConflicts())
    }

    /// Seeded launches, terminations and reused process IDs, reported by the running list, the notifications or both in
    /// either order, with full scans in between: once every report of a step has arrived, the snapshot holds what a
    /// full scan of the list finds, and the matcher was asked once per launched process plus once per app a full scan
    /// listed.
    @Test(arguments: [UInt64(1), 2, 3]) func randomReportsKeepTheConflictsOfAFullScan(seed: UInt64) async {
        let counter = CountingMatcher()
        let harness = SignalsHarness(match: counter.match)
        let identities = [booster, tint, shade, editor,
                          RunningAppInfo(bundleID: "com.example.dimmer.pro", processID: 0, bundleURL: dimmerURL),
                          RunningAppInfo(bundleID: nil, processID: 0, executableName: "example-boost", isRegular: false),
                          RunningAppInfo(bundleID: "com.example.helper.xpc", processID: 0, isRegular: false)]
        harness.apps.teams[dimmerURL] = "TEAM123456"
        await harness.start()
        var random = SeededGenerator(seed: seed)
        var expectedAsks = 0
        let center = harness.platform.workspaceCenter
        for step in 0..<300 {
            let running = harness.apps.apps
            let roll = Int.random(in: 0..<10, using: &random)
            if roll < 5 || running.isEmpty {                                  // a launch, under a free (maybe reused) PID
                let used = Set(running.map(\.processID))
                guard let pid = (Int32(1000)...Int32(1011)).filter({ !used.contains($0) }).randomElement(using: &random),
                      var app = identities.randomElement(using: &random) else { continue }
                app.processID = pid
                expectedAsks += 1
                let notifyFirst = app.isRegular && Bool.random(using: &random)
                if notifyFirst { harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: app) }
                harness.apps.apps.append(app)
                harness.platform.changeRunningList(added: [app])
                if app.isRegular && !notifyFirst && Bool.random(using: &random) {
                    harness.platform.post(NSWorkspace.didLaunchApplicationNotification, in: center, app: app)
                }
            } else if roll < 9, let app = running.randomElement(using: &random) {   // a termination
                let notifyFirst = app.isRegular && Bool.random(using: &random)
                if notifyFirst { harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center, app: app) }
                harness.apps.apps.removeAll { $0.processID == app.processID }
                harness.platform.changeRunningList(removed: [app])
                if app.isRegular && !notifyFirst {
                    harness.platform.post(NSWorkspace.didTerminateApplicationNotification, in: center, app: app)
                }
            } else {                                                          // a full scan: boost, session or wake
                expectedAsks += running.count
                switch Int.random(in: 0..<3, using: &random) {
                case 0: harness.monitor.setBoostActive(true); harness.monitor.setBoostActive(false)
                case 1: harness.platform.post(NSWorkspace.sessionDidBecomeActiveNotification, in: center)
                default: harness.platform.post(NSWorkspace.didWakeNotification, in: center)
                }
            }
            #expect(harness.monitor.snapshot.conflicts == harness.probe.runningConflicts(), "seed \(seed), step \(step)")
            expectedAsks += harness.apps.apps.count                           // the reference scan just above
            #expect(counter.asked.count == expectedAsks, "seed \(seed), step \(step)")
        }
    }

    @Test func driftIsAttributedToARunningAppFirst() async {
        let apps = FakeRunningApps()
        apps.apps = [shade, tint]
        apps.processes = [ProcessScanner.Process(processID: 400, executableName: "example-boost", bundlePath: nil, bundleID: nil)]
        let probe = probe(apps)
        #expect(await probe.attributeDrift()?.entryID == "test-tint")      // S2 running: named, no scan
        #expect(apps.scans == 0)
    }

    @Test func otherwiseOneProcessScanLooksForACulprit() async {
        let apps = FakeRunningApps()
        apps.apps = [shade, editor]                                         // a benign app is never the culprit
        apps.processes = [
            ProcessScanner.Process(processID: 203, executableName: "Shade", bundlePath: nil, bundleID: "com.example.shade"),
            ProcessScanner.Process(processID: 401, executableName: "launchd", bundlePath: nil, bundleID: nil),
            ProcessScanner.Process(processID: 402, executableName: "example-boost", bundlePath: nil, bundleID: nil),
        ]
        let culprit = await probe(apps).attributeDrift()
        #expect(culprit?.entryID == "test-tool" && culprit?.processID == 402)
        #expect(culprit?.displayName == "example-boost")
        #expect(apps.scans == 1)
    }

    @Test func nobodyToNameIsNil() async {
        let apps = FakeRunningApps()
        apps.apps = [editor]
        apps.processes = [ProcessScanner.Process(processID: 401, executableName: "launchd", bundlePath: nil, bundleID: nil)]
        #expect(await probe(apps).attributeDrift() == nil)
    }

    @Test func bundlePathsComeFromMainExecutables() {
        #expect(ProcessScanner.bundlePath(forExecutable: "/Applications/Tint.app/Contents/MacOS/Tint") == "/Applications/Tint.app")
        #expect(ProcessScanner.bundlePath(forExecutable:
            "/Applications/Big.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper")
            == "/Applications/Big.app/Contents/Frameworks/Helper.app")
        #expect(ProcessScanner.bundlePath(forExecutable: "/usr/local/bin/example-boost") == nil)
        #expect(ProcessScanner.bundlePath(forExecutable: "/Applications/Tint.app/Contents/Resources/tool") == nil)
    }
}
