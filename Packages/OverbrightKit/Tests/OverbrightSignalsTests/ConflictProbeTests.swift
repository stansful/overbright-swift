// OverbrightSignalsTests/ConflictProbeTests.swift — running conflicts, scripted launches and terminations, team reads,
// and drift attribution with the libproc fallback. ARCHITECTURE.md §3.6, §7.2, §10.8. Synthetic IDs only (D3).
import AppKit
import OverbrightCore
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
