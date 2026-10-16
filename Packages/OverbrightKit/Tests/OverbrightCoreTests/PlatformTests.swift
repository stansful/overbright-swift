// OverbrightCoreTests/PlatformTests.swift — adapted from Cranny's PlatformTests (the owner's MIT code): files, debounce,
// versions, durations, launch arguments (with Overbright's switches of ARCHITECTURE.md §8.5), snapshot output; plus
// MachineIdentity, SystemTimeSource and the journal ring buffer.
import Foundation
import Testing
@testable import OverbrightCore

// MARK: - Files

private struct Document: Codable, Equatable, Sendable {
    var title: String
    var items: [Int]
}

@Test func jsonFileStoreRoundTripsAndSetsCorruptFilesAside() async throws {
    let paths = AppPaths.temporary()
    #expect(!FileManager.default.fileExists(atPath: paths.root.path))           // nothing is created up front
    let directory = try paths.cacheDirectory(for: "strategy")
    #expect(directory.path.hasSuffix("/Caches/strategy"))
    let url = directory.appending(path: "strategy-cache.json")
    let store = JSONFileStore(url: url, defaultValue: Document(title: "default", items: []))

    #expect(await store.load() == Document(title: "default", items: []))     // missing file → default
    try await store.save(Document(title: "Built-in", items: [1, 2, 3]))
    #expect(await store.load() == Document(title: "Built-in", items: [1, 2, 3]))

    try Data("{ not json".utf8).write(to: url)
    #expect(await store.load() == Document(title: "default", items: []))     // corrupt → default …
    let siblings = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(!siblings.contains("strategy-cache.json"))                         // … and the file is moved aside,
    #expect(siblings.contains { $0.hasPrefix("strategy-cache.json.corrupt-") }) // never silently overwritten
    try? FileManager.default.removeItem(at: paths.root.deletingLastPathComponent())
}

@Test func appPathsLiveUnderTheBundleIdentifier() throws {
    #expect(Log.subsystem == "app.overbright.Overbright")
    #expect(AppPaths.live.root.lastPathComponent == "app.overbright.Overbright")
    #expect(AppPaths.live.root.deletingLastPathComponent().lastPathComponent == "Application Support")
    #expect(AppPaths.live.caches.lastPathComponent == "app.overbright.Overbright")
    let paths = AppPaths.temporary()
    let selfTest = try paths.directory(for: AppPaths.selfTestFolder)
    #expect(selfTest.path.hasSuffix("/Support/SelfTest") && FileManager.default.fileExists(atPath: selfTest.path))
    try? FileManager.default.removeItem(at: paths.root.deletingLastPathComponent())
}

// MARK: - Debounce

/// What a debounced action saw (written on the main actor).
@MainActor private final class DebounceProbe { var priority: TaskPriority?; var runs = 0 }

/// A debouncer given a priority runs its action at it (background saves at utility, so the `@concurrent` work they
/// await does too).
@MainActor @Test func aDebouncedActionRunsAtItsDebouncersPriority() async {
    let probe = DebounceProbe()
    let debouncer = Debouncer(delay: .milliseconds(1), priority: .utility)
    debouncer.schedule { probe.priority = Task.currentPriority }
    for _ in 0..<3000 where probe.priority == nil { try? await Task.sleep(for: .milliseconds(10)) }
    #expect(probe.priority == .utility)
}

@MainActor @Test func aDebouncerRunsOnlyTheLastActionAndCancelDropsIt() async {
    let probe = DebounceProbe()
    let debouncer = Debouncer(delay: .milliseconds(20))
    debouncer.schedule { probe.runs += 1 }
    debouncer.schedule { probe.runs += 10 }
    for _ in 0..<3000 where probe.runs == 0 { try? await Task.sleep(for: .milliseconds(10)) }
    #expect(probe.runs == 10)
    debouncer.schedule { probe.runs += 100 }
    debouncer.cancel()
    try? await Task.sleep(for: .milliseconds(100))
    #expect(probe.runs == 10)
}

// MARK: - Versions and durations

@Test func semanticVersionsParseAndOrder() throws {
    #expect(SemanticVersion("v0.1.0")?.description == "0.1.0")
    #expect(SemanticVersion("1.2.3-rc.1")?.prerelease == "rc.1")
    #expect(SemanticVersion("") == nil && SemanticVersion("one.two") == nil && SemanticVersion("1.2.3.4") == nil)
    #expect(try #require(SemanticVersion("v1.2")) < #require(SemanticVersion("1.10.0")))
    #expect(try #require(SemanticVersion("1.0.0-beta.2")) < #require(SemanticVersion("1.0.0")))
    #expect(try #require(SemanticVersion("1.0.0-beta.2")) < #require(SemanticVersion("1.0.0-beta.10")))
    #expect(try #require(SemanticVersion("0.9.9")) < #require(SemanticVersion("0.10.0")))
    #expect(!(try #require(SemanticVersion("1.0.0")) < #require(SemanticVersion("1.0.0"))))
}

@Test func durationsConvertToSeconds() {
    #expect(Duration.milliseconds(1500).timeInterval == 1.5)
    #expect(Duration.seconds(-2).timeInterval == -2)
    #expect(Duration.zero.timeInterval == 0)
}

// MARK: - Launch arguments (§8.5)

@Test func launchArgumentsParseValuesAndFlags() {
    let a = LaunchArguments(["Overbright", "--qa-state", "boostedSafe", "--qa-panel", "--qa-exit-after", "8",
                             "--qa-welcome", "2", "--qa-last"])
    #expect(a.value(after: "--qa-state") == "boostedSafe" && a.contains("--qa-panel") && !a.contains("--qa-other"))
    #expect(a.double(after: "--qa-exit-after") == 8 && a.int(after: "--qa-welcome") == 2)
    #expect(a.int(after: "--qa-state") == nil && a.value(after: "--qa-last") == nil && a.value(after: "--nope") == nil)
}

@Test func releaseSwitchesAndCommandLineModes() {
    let plain = LaunchArguments(["Overbright"])
    #expect(!plain.startsOff && !plain.restoresGamma && plain.diagnosticsPath == nil && !plain.runsMonitor)
    #expect(!plain.isCommandLineMode && plain.debugOnlySwitches.isEmpty)

    #expect(LaunchArguments(["Overbright", "--off"]).startsOff)
    #expect(LaunchArguments(["Overbright", "--restore-gamma"]).isCommandLineMode)
    #expect(LaunchArguments(["Overbright", "--diagnostics", "/tmp/d.json"]).diagnosticsPath == "/tmp/d.json")
    #expect(LaunchArguments(["Overbright", "--diagnostics", "-"]).diagnosticsPath == "-")
    #expect(LaunchArguments(["Overbright", "--diagnostics"]).diagnosticsPath == "-")              // stdout
    #expect(LaunchArguments(["Overbright", "--diagnostics", "--off"]).diagnosticsPath == "-")     // never a flag

    let monitor = LaunchArguments(["Overbright", "--monitor", "2.5"])
    #expect(monitor.runsMonitor && monitor.monitorDuration == .milliseconds(2500) && monitor.isCommandLineMode)
    #expect(LaunchArguments(["Overbright", "--monitor"]).monitorDuration == nil)                  // until Ctrl-C
    #expect(LaunchArguments(["Overbright", "--monitor", "--off"]).monitorDuration == nil)

}

/// §8.5: the parser names every Debug-only switch (a Release build refuses to start with one; the shell decides),
/// and never a Release switch or a value.
@Test func debugOnlySwitchesAreNamed() {
    let qa = LaunchArguments(["/Applications/Overbright.app/Contents/MacOS/Overbright", "--off", "--qa-simulate",
                              "builtin-xdr-lid-open", "--qa-defaults-suite", "app.overbright.Overbright.dev",
                              "-OverbrightQAAppearance", "dark", "--diagnostics", "-"])
    #expect(qa.debugOnlySwitches == ["--qa-simulate", "--qa-defaults-suite", "-OverbrightQAAppearance"])
    #expect(LaunchArguments(["Overbright", "--qa-panel"]).debugOnlySwitches == ["--qa-panel"])
    let release = LaunchArguments(["Overbright", "--off", "--monitor", "2", "--diagnostics", "/tmp/qa-report.json",
                                   "--restore-gamma"])
    #expect(release.debugOnlySwitches.isEmpty)
}

@Test func qaSwitchesOfTheArchitecture() throws {
    let a = LaunchArguments(["Overbright", "--off", "--qa-simulate", "mpg322ux-hdr-on", "--qa-defaults-suite",
                             "app.overbright.Overbright.dev", "--qa-menu", "--qa-hud", "0.5", "--qa-settings",
                             "displays#capMode", "--qa-calibration", "0B21E7F1-0000-4000-8000-000000000001",
                             "--qa-help", "no-extra-range", "--qa-snapshot", "/tmp/shots", "--qa-snapshot-at", "1.5",
                             "--qa-update-check", "--qa-hang-main", "5,4"])
    #expect(a.startsOff && a.qaSimulateFixture == "mpg322ux-hdr-on")
    #expect(a.qaSimulateFixture.flatMap(DisplayFixture.init(rawValue:)) == .mpg322uxHDROn && a.qaSimulates)
    for bare in [["Overbright", "--off", "--qa-simulate"], ["Overbright", "--qa-simulate", "--off"]] {
        let arguments = LaunchArguments(bare)                    // the switch without a name still simulates
        #expect(arguments.qaSimulates && arguments.qaSimulateFixture == nil && arguments.startsOff, "\(bare)")
    }
    #expect(!LaunchArguments(["Overbright", "--off"]).qaSimulates)
    #expect(a.qaDefaultsSuite == "app.overbright.Overbright.dev")
    #expect(a.qaOpensMenu && !a.qaOpensPanel && a.qaHUDLevel == "0.5" && a.qaSettingsPane == "displays#capMode")
    #expect(a.qaCalibrationDisplay == "0B21E7F1-0000-4000-8000-000000000001" && a.qaHelpAnchor == "no-extra-range")
    #expect(a.qaSnapshotDirectory == "/tmp/shots" && a.qaSnapshotAt == 1.5 && a.qaRunsUpdateCheck)
    let hang = try #require(a.qaHangMain)
    #expect(hang.delay == .seconds(5) && hang.duration == .seconds(4))
    #expect(LaunchArguments(["--qa-hang-main", "5"]).qaHangMain == nil)
    #expect(LaunchArguments(["--qa-hang-main", "x,4"]).qaHangMain == nil)
    #expect(LaunchArguments(["--qa-welcome", "done"]).qaWelcomeStep == "done")
    #expect(LaunchArguments(["--qa-state", "paused"]).qaState == "paused")
    #expect(LaunchArguments([]).qaSnapshotDirectory == nil && LaunchArguments([]).qaExitAfter == nil)
}

// MARK: - Snapshot output (opt-in test suites)

@Test func snapshotSuitesShareOneVariableAndWriteOneFolderEach() {
    let set = ["OVERBRIGHT_SNAPSHOT_DIR": "/tmp/shots", "OVERBRIGHT_SNAPSHOT_LANGUAGE": "ru"]
    #expect(SnapshotOutput.directory("PanelUI", environment: set)?.path(percentEncoded: false) == "/tmp/shots/PanelUI/")
    #expect(SnapshotOutput.directory("Onboarding", environment: set)?.hasDirectoryPath == true)
    #expect(SnapshotOutput.language(environment: set) == "ru")
    // Not set, or set empty: the suites skip themselves (or write nothing) and render in English.
    for unset in [[:], ["OVERBRIGHT_SNAPSHOT_DIR": "", "OVERBRIGHT_SNAPSHOT_LANGUAGE": ""]] as [[String: String]] {
        #expect(SnapshotOutput.directory("PanelUI", environment: unset) == nil)
        #expect(SnapshotOutput.language(environment: unset) == nil)
    }
}

// MARK: - Machine, time, journal

/// Read-only sysctl and ProcessInfo reads; nothing about the display is touched.
@Test func machineIdentityReadsTheModelAndBuild() {
    let machine = MachineIdentity.current()
    #expect(!machine.model.isEmpty && machine.model != "unknown")
    #expect(!machine.osBuild.isEmpty && machine.osBuild != "unknown")
    #expect(machine.osMajor >= 14)
    let v = ProcessInfo.processInfo.operatingSystemVersion
    #expect((machine.osMajor, machine.osMinor, machine.osPatch) == (v.majorVersion, v.minorVersion, v.patchVersion))
}

@Test func systemTimeSourceIsMonotonicAndSleeps() async throws {
    let time = SystemTimeSource()
    let a = time.now
    try await time.sleep(for: .milliseconds(5))
    let b = time.now
    #expect(b > a && b - a >= .milliseconds(4))
    try await time.sleep(for: .zero)                                           // returns at once
    let cancelled = Task { try await time.sleep(for: .seconds(30)) }
    cancelled.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.value }
}

@Test func theJournalKeepsTheLastEventsInOrder() async {
    let journal = RingBufferJournal(capacity: 3)
    for i in 0..<5 { journal.record(JournalEvent(seconds: Double(i), category: "engine", display: nil, code: "e\(i)")) }
    #expect(journal.snapshot().map(\.code) == ["e2", "e3", "e4"])
    #expect(RingBufferJournal().capacity == 500)

    // Recorded from many threads at once (the watchdog and the signal queue record off the main actor).
    let shared = RingBufferJournal()
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<600 {
            group.addTask { shared.record(JournalEvent(seconds: Double(i), category: "gamma", display: nil, code: "w")) }
        }
    }
    #expect(shared.snapshot().count == 500)
}
