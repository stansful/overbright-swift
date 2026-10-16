// OverbrightAppShellTests/QADefaultsTests.swift — `--qa-defaults-suite <name>`: a Debug QA run keeps every setting it
// writes in its own suite and never writes the app's preferences domain (ARCHITECTURE.md §8.2, §8.5). Ported from
// Cranny's QADefaultsTests (the owner's MIT code). No test here opens a real suite (that would leave a plist in
// ~/Library/Preferences): the suite is a recording in-memory stand-in. In this process the standard domain is the
// test runner's, so that is where a leak would land; every key the run wrote must be absent from it.
import AppKit
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

/// An in-memory `UserDefaults` that records the key of every write (the QA suite's stand-in). `@unchecked Sendable`:
/// its state is behind a lock.
private nonisolated final class RecordingDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]
    private var writes: [String] = []

    var written: [String] { lock.withLock { writes } }

    override func object(forKey defaultName: String) -> Any? { lock.withLock { values[defaultName] } }
    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock {
            writes.append(defaultName)
            values[defaultName] = value
        }
    }
    override func removeObject(forKey defaultName: String) { set(nil, forKey: defaultName) }
    override func dictionaryRepresentation() -> [String: Any] { lock.withLock { values } }
    override func data(forKey defaultName: String) -> Data? { object(forKey: defaultName) as? Data }
    override func string(forKey defaultName: String) -> String? { object(forKey: defaultName) as? String }
    override func set(_ value: Int, forKey defaultName: String) { set(NSNumber(value: value), forKey: defaultName) }
    override func set(_ value: Double, forKey defaultName: String) { set(NSNumber(value: value), forKey: defaultName) }
    override func set(_ value: Bool, forKey defaultName: String) { set(NSNumber(value: value), forKey: defaultName) }
}

/// What Overbright could have written to the standard domain of this process: its settings.
private func overbrightState(in defaults: UserDefaults) -> [String: String] {
    defaults.dictionaryRepresentation().filter { $0.key.hasPrefix(SettingsStore.keyPrefix) }.mapValues { "\($0)" }
}

@MainActor @Suite struct QADefaultsTests {
    private let suiteName = "app.overbright.Overbright.qa-test"

    @Test func withoutTheSwitchTheAppUsesItsPreferences() {
        #expect(QAHooks.defaults(LaunchArguments(["Overbright", "--qa-panel"])) == nil)
        let standard = ShellDefaults.forLaunch(LaunchArguments(["Overbright"]))
        #expect(standard.defaults === UserDefaults.standard && standard.qaSuite == nil && standard.autosavesWindowFrames)
    }

    @Test func theSwitchOpensTheNamedSuite() throws {
        var opened: [String] = []
        let suite = RecordingDefaults()
        let qa = try #require(QAHooks.defaults(LaunchArguments(["Overbright", "--qa-defaults-suite", suiteName]),
                                               ownDomain: "app.overbright.Overbright") { name in
            opened.append(name)
            return suite
        })
        #expect(opened == [suiteName])
        #expect(qa.defaults === suite && qa.qaSuite == suiteName)
        #expect(!qa.autosavesWindowFrames)                       // AppKit's frame autosave writes the standard domain
    }

    /// A name that is the app's own domain, a global one, missing or another argument is refused: the run keeps its
    /// settings in memory, never in the standard domain.
    @Test func aSuiteThatWouldBeTheUsersPreferencesIsRefused() throws {
        for arguments in [["--qa-defaults-suite", "app.overbright.Overbright"],
                          ["--qa-defaults-suite", "App.Overbright.Overbright"],
                          ["--qa-defaults-suite", "com.example.own"], ["--qa-defaults-suite", "NSGlobalDomain"],
                          ["--qa-defaults-suite", ".GlobalPreferences"], ["--qa-defaults-suite", ""],
                          ["--qa-defaults-suite", "--qa-panel"], ["--qa-defaults-suite"]] {
            let qa = try #require(QAHooks.defaults(LaunchArguments(["Overbright"] + arguments),
                                                   ownDomain: "com.example.own") { _ in
                Issue.record("opened a suite for \(arguments)")
                return nil
            })
            #expect(qa.defaults is InMemoryDefaults && qa.defaults !== UserDefaults.standard, "\(arguments)")
            #expect(!qa.autosavesWindowFrames)
        }
    }

    /// With the switch on, the settings store the composition root builds, the one-time upgrade, setting writes,
    /// Reset All and its Undo all land in the suite, and the standard domain gets nothing.
    @Test func withTheSwitchTheStandardDomainIsNeverWritten() throws {
        let before = overbrightState(in: .standard)
        let suite = RecordingDefaults()
        let qa = try #require(QAHooks.defaults(LaunchArguments(["Overbright", "--qa-defaults-suite", suiteName]),
                                               ownDomain: "app.overbright.Overbright") { _ in suite })
        let shell = CompositionRoot.makeShell(
            settings: SettingsStore(defaults: qa.defaults), paths: .temporary(), machine: DisplayFixture.ownerMachine,
            time: ManualTimeSource(), ports: CompositionRoot.simulatedPorts(.builtinXDRLidOpen, time: ManualTimeSource()))
        let settings = shell.services.settings
        settings.upgradeStoredSettings()
        settings[GeneralSettings.showsHUD] = false
        settings[DisplaySettings.linkLevels] = true
        settings[GeneralSettings.clickAction] = .toggle
        settings.reset(GeneralSettings.clickAction)
        let control = ShellAppControl(settings: settings)
        control.resetAllSettings()
        control.undoResetAllSettings()

        #expect(Set(suite.written).isSuperset(of: ["overbright.revision", "overbright.general.showsHUD",
                                                   "overbright.displays.linkLevels", "overbright.general.clickAction"]))
        #expect(!settings[GeneralSettings.showsHUD] && settings[DisplaySettings.linkLevels])
        #expect(overbrightState(in: .standard) == before)                      // the app's preferences: untouched
        let leaked = Set(suite.written).filter { UserDefaults.standard.object(forKey: $0) != nil }
        #expect(leaked.isEmpty, "in the standard domain: \(leaked.sorted())")
    }
}
