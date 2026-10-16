// OverbrightAppShell/App/CompositionRoot.swift — the ONLY place that knows concrete types. ARCHITECTURE.md §3.9,
// §3.11, §7.4, §10.0 (shared shell file, contract owner), §10.15 (WP13 wires every real implementation).
//
// Two wirings:
// - `--qa-simulate <fixture>` (Debug only): every display port is a Core fake over the fixture (`FakeGammaPort`,
//   `ScriptedHeadroom`, `FakeDisplayDirectory`, `FakeTriggerFactory`), with fake signals and conflicts. Nothing
//   touches a display (D24). An unknown fixture name falls back to `builtin-xdr-lid-open`, never to real ports.
// - Real ports: in WP0a only the READ-ONLY display ports exist (`CoreGraphicsGamma` refuses writes,
//   `SystemHeadroomPort`, `SystemDisplayDirectory`); triggers, signals, conflicts, Fill Light, shortcuts and updates are
//   placeholders (fakes that open nothing) until their packages land, and `--diagnostics` reports them as null.
// Constructing either wiring does no I/O, hardware or network access (test `constructingServicesTouchesNoHardware`);
// `ServiceLifecycle.start()` does. Lifecycle order: Displays → … → Boost last; stop in reverse, Boost first (D7).
//
// A Release build never falls back silently: it refuses to start when given a Debug-only switch (`refusedSwitches`),
// so a QA command meant for the simulated ports never runs on the real ones. The D27 single-instance exemption
// follows the wiring, not the arguments (`skipsSingleInstanceCheck`): only a command-line mode or a launch that
// really got the simulated ports may run next to another Overbright.
import CoreGraphics
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightDisplays
import OverbrightPolicy
import os

private let log = Log.logger(.app)

/// Builds the wiring.
enum CompositionRoot {
    /// Whether this is a Debug build (the only one that honours the QA switches of §8.5).
    static let isDebugBuild: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// The Debug-only switches a build refuses to start with: none in a Debug build; in a Release build every
    /// `--qa-…` and `-OverbrightQA…` switch present (the app logs them and exits with `EX_USAGE` before anything
    /// starts, rather than ignoring them and wiring the real ports).
    static func refusedSwitches(_ arguments: LaunchArguments, debugBuild: Bool = isDebugBuild) -> [String] {
        debugBuild ? [] : arguments.debugOnlySwitches
    }

    /// D27: a command-line mode, or a launch wired to the simulated ports, skips the single-instance check. Decided on
    /// what `ports(for:time:)` actually returned, so a launch that got the real ports is never exempt.
    static func skipsSingleInstanceCheck(_ arguments: LaunchArguments, ports: ShellPorts) -> Bool {
        arguments.isCommandLineMode || ports.fixture != nil
    }

    /// The ports for this launch: `--qa-simulate` (Debug builds only; a Release build has already refused the switch,
    /// see `refusedSwitches`) or the real ones.
    static func ports(for arguments: LaunchArguments, time: any TimeSource) -> ShellPorts {
        #if DEBUG
        if let name = arguments.qaSimulateFixture {
            let fixture = DisplayFixture(rawValue: name) ?? {
                log.error("QA: unknown --qa-simulate fixture \(name, privacy: .public); using builtin-xdr-lid-open")
                return .builtinXDRLidOpen
            }()
            return simulatedPorts(fixture, time: time)
        }
        #endif
        return livePorts(time: time)
    }

    /// Core fakes over `fixture`: nothing reaches a display.
    static func simulatedPorts(_ fixture: DisplayFixture, time: any TimeSource) -> ShellPorts {
        let headroom = ScriptedHeadroom(fixture: fixture, time: time)
        let directory = FakeDisplayDirectory(fixture: fixture)
        return ShellPorts(gamma: FakeGammaPort(fixture: fixture, time: time), headroom: headroom, displays: directory,
                          triggers: FakeTriggerFactory(headroom: headroom), signals: FakeSystemSignals(),
                          conflicts: FakeConflictProbe(), fillLight: PreviewFillLightControl(),
                          shortcuts: PreviewShortcutCenter(), updates: PreviewUpdateChecking(),
                          readDisplays: { directory.displays }, profileHasVCGT: { _ in nil },
                          lifecycle: [], placeholders: [], fixture: fixture)
    }

    /// The real ports. WP0a: the read-only display ports; placeholders for the rest (see the file header).
    static func livePorts(time: any TimeSource) -> ShellPorts {
        let gamma = CoreGraphicsGamma()
        let directory = SystemDisplayDirectory()
        return ShellPorts(gamma: gamma, headroom: SystemHeadroomPort(time: time), displays: directory,
                          triggers: FakeTriggerFactory(),                 // WP3: SystemTriggerFactory
                          signals: FakeSystemSignals(),                   // WP6: SignalsMonitor
                          conflicts: FakeConflictProbe(),                 // WP6: RunningAppsConflictProbe
                          fillLight: PreviewFillLightControl(),           // WP7: FillLightController
                          shortcuts: PreviewShortcutCenter(),             // WP0b: HotKeyCenter
                          updates: PreviewUpdateChecking(),               // WP0b: UpdateChecker
                          readDisplays: { SystemDisplayDirectory.onlineDisplays() },
                          profileHasVCGT: { gamma.profileHasVCGT(of: $0) },
                          lifecycle: [directory], placeholders: [.signals, .conflicts], fixture: nil)
    }

    /// The hub and the lifecycle over `ports`. `scriptedStatus` (`--qa-state`) replaces the engine with a
    /// `PreviewBoostControl` showing that status.
    static func makeShell(settings: SettingsStore, paths: AppPaths, machine: MachineIdentity, time: any TimeSource,
                          ports: ShellPorts, scriptedStatus: BoostStatus? = nil) -> Shell {
        let journal = RingBufferJournal()
        let ownEDRSurfaces = OwnEDRSurfaces()
        var lifecycle = ports.lifecycle
        let boost: any BoostControl
        if let scriptedStatus {
            boost = PreviewBoostControl(status: scriptedStatus, machine: machine)
        } else {
            let engine = BoostEngine(settings: settings, machine: machine, time: time, journal: journal,
                                     ownEDRSurfaces: ownEDRSurfaces, displays: ports.displays, signals: ports.signals,
                                     gamma: ports.gamma, headroom: ports.headroom, triggers: ports.triggers,
                                     conflicts: ports.conflicts)
            boost = engine
            lifecycle.append(engine)                                       // Boost starts last, stops first (D7)
        }
        let services = OverbrightServices(settings: settings, paths: paths, machine: machine, time: time,
                                          journal: journal, announcer: Announcer(), ownEDRSurfaces: ownEDRSurfaces,
                                          displays: ports.displays, signals: ports.signals, boost: boost,
                                          fillLight: ports.fillLight, shortcuts: ports.shortcuts,
                                          updates: ports.updates)
        let rescue = LaunchRescue(gamma: ports.gamma, conflicts: ports.conflicts, signals: ports.signals,
                                  journal: journal)
        return Shell(services: services, ports: ports, lifecycle: lifecycle, rescue: rescue)
    }

    /// The diagnostics inputs of `shell` (`--diagnostics`: bundle facts; Copy Diagnostics: the journal).
    static func diagnosticsInputs(_ shell: Shell, forClipboard: Bool) -> DiagnosticsReport.Inputs {
        let ports = shell.ports
        return DiagnosticsReport.Inputs(
            settings: shell.services.settings, machine: shell.services.machine, journal: shell.services.journal,
            iconVisibility: shell.services.app?.iconVisibility ?? .visible, gamma: ports.gamma,
            headroom: ports.headroom, triggers: ports.triggers, displays: ports.readDisplays(),
            signals: ports.placeholders.contains(.signals) ? nil : ports.signals,
            conflicts: ports.placeholders.contains(.conflicts) ? nil : ports.conflicts,
            profileHasVCGT: ports.profileHasVCGT, simulatedFixture: ports.fixture?.rawValue,
            includesBundleFacts: !forClipboard, includesJournal: forClipboard)
    }
}
