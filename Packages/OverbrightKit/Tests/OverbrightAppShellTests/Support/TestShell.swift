// OverbrightAppShellTests/Support/TestShell.swift — the composition root's simulated wiring for tests: in-memory
// settings, temporary folders, a manual clock, a silent announcer and a hot-key registrar that records instead of
// registering system-wide shortcuts. ARCHITECTURE.md §3.9, §9.1 (no test changes system state, D24).
import Foundation
import OverbrightCore
import OverbrightHotKeys
@testable import OverbrightAppShell

/// Builds shells over the simulated ports.
@MainActor enum TestShell {
    /// A context over `settings` and `time` with the fixture's Mac.
    static func context(fixture: DisplayFixture = .builtinXDRLidOpen,
                        settings: SettingsStore = SettingsStore(defaults: InMemoryDefaults()),
                        time: any TimeSource = ManualTimeSource()) -> ShellContext {
        ShellContext(settings: settings, paths: .temporary(), machine: fixture.machine, time: time,
                     journal: RingBufferJournal(capacity: 5_000), announcer: Announcer(post: { _ in }, now: { 0 }))
    }

    /// The simulated ports of `fixture`, with `hotKeys` recording.
    static func ports(_ fixture: DisplayFixture = .builtinXDRLidOpen, context: ShellContext,
                      hotKeys: RecordingHotKeys = RecordingHotKeys()) -> ShellPorts {
        CompositionRoot.simulatedPorts(fixture, context: context, hotKeys: hotKeys)
    }

    /// A whole shell over the simulated ports of `fixture`.
    static func shell(_ fixture: DisplayFixture = .builtinXDRLidOpen, context: ShellContext? = nil,
                      hotKeys: RecordingHotKeys = RecordingHotKeys(), scriptedStatus: BoostStatus? = nil) -> Shell {
        let context = context ?? self.context(fixture: fixture)
        return CompositionRoot.makeShell(context, ports: ports(fixture, context: context, hotKeys: hotKeys),
                                         scriptedStatus: scriptedStatus)
    }
}

/// A `HotKeyRegistrar` that registers nothing system-wide: it records the combos and can "press" one.
@MainActor final class RecordingHotKeys: HotKeyRegistrar {
    var onPress: (@MainActor (UInt32) -> Void)?
    private(set) var registered: [UInt32: KeyCombo] = [:]
    private var nextID: UInt32 = 1

    func register(_ combo: KeyCombo) -> UInt32? {
        let id = nextID
        nextID += 1
        registered[id] = combo
        return id
    }

    func unregister(_ id: UInt32) { registered[id] = nil }

    /// Presses the registered hot key with `combo`; false when none is registered.
    @discardableResult
    func press(_ combo: KeyCombo) -> Bool {
        guard let id = registered.first(where: { $0.value == combo })?.key else { return false }
        onPress?(id)
        return true
    }
}
