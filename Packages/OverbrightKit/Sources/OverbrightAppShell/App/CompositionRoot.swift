// OverbrightAppShell/App/CompositionRoot.swift — the ONLY place that knows concrete types. ARCHITECTURE.md §3.9,
// §3.11, §7.4, §10.0 (shared shell file), §10.15.
//
// Two wirings:
// - Real ports: one `CoreGraphicsGamma` (its write gate serializes every table write and the restore of the process,
//   so the directory's read checks get the same instance), `SystemDisplayDirectory`, `SystemHeadroomPort`,
//   `SystemTriggerFactory`, `RunningAppsConflictProbe` over Policy's catalogue, `SignalsMonitor`, `FillLightController`
//   with EDR frame windows, `HotKeyCenter`, `UpdateChecker`, the app's `SMAppService` login item and the control's real
//   outlet (a silent one in a Debug run with its own `--qa-defaults-suite`, which never writes the app's preferences
//   domain: `controlOutlet(for:)`). Displays' reconfiguration and screen events are relayed into Signals' event stream
//   synchronously, so a `displayRemoved` reaches every display controller before the reconfiguration callback returns
//   (§4.3, §7.1).
// - `--qa-simulate [fixture]` (a Debug switch): every display port is a Core fake over the fixture (`FakeGammaPort`,
//   `ScriptedHeadroom`, `FakeDisplayDirectory`, `FakeTriggerFactory`), with fake signals and conflicts, Fill Light's
//   SDR stand-in windows, an in-memory login item and a silent control outlet; the shortcuts and the update check are
//   the real ones (they touch no display). Nothing touches a display (D24). The switch alone selects this wiring
//   (`simulatedFixture(for:)`): a missing name (`--off --qa-simulate`, or another switch right after it) or an unknown
//   one is logged and falls back to `builtin-xdr-lid-open`, never to real ports. This holds in every build
//   configuration, so it does not depend on the Release refusal below having run first.
// Constructing either wiring does no I/O, hardware or network access (test `constructingServicesTouchesNoHardware`);
// `ServiceLifecycle.start()` does. Lifecycle order: Displays → Triggers → Signals → FillLight → HotKeys → Updates →
// Intents → Boost last; stop in reverse, Boost first (D7, `ServiceStack`). The launch check runs before the first
// service; one skipped off the console runs again right before the engine starts if the session is on the console by
// then (D27: a return to the console before Signals listened would otherwise reach nobody).
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
import OverbrightFillLight
import OverbrightHotKeys
import OverbrightIntents
import OverbrightPolicy
import OverbrightSignals
import OverbrightTriggers
import OverbrightUpdates
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

    /// The strategy cache's file name under `AppPaths.caches` (§8.2).
    static let strategyCacheFileName = "strategy-cache.json"

    /// How many records the simulated fakes keep (their whole history would grow with every write of a long run).
    /// Nothing reads more than the newest few: QA dumps, diagnostics and the soak read `writeCount` and
    /// `openWindowCount`, which are never trimmed. 256 kept 256–512 full tables, a 3.8–7.7 MB saw-tooth in every QA
    /// footprint and in the soak's growth fit (energy work, H3).
    static let qaRecordLimit = 16

    /// The Debug-only switches a build refuses to start with: none in a Debug build; in a Release build every
    /// `--qa-…` and `-OverbrightQA…` switch present (the app logs them and exits with `EX_USAGE` before anything
    /// starts, rather than ignoring them and wiring the real ports).
    static func refusedSwitches(_ arguments: LaunchArguments, debugBuild: Bool = isDebugBuild) -> [String] {
        debugBuild ? [] : arguments.debugOnlySwitches
    }

    /// D27: a command-line mode, or a launch wired to the simulated ports, skips the single-instance check. Decided on
    /// what `ports(for:context:)` actually returned, so a launch that got the real ports is never exempt.
    static func skipsSingleInstanceCheck(_ arguments: LaunchArguments, ports: ShellPorts) -> Bool {
        arguments.isCommandLineMode || ports.fixture != nil
    }

    /// The fixture a launch simulates, nil only without `--qa-simulate`: the named fixture, or `builtin-xdr-lid-open`
    /// (logged) when the name is missing or unknown. Pure apart from that log line, so tests check the decision
    /// without constructing the real ports.
    static func simulatedFixture(for arguments: LaunchArguments) -> DisplayFixture? {
        guard arguments.qaSimulates else { return nil }
        guard let name = arguments.qaSimulateFixture else {
            log.error("QA: --qa-simulate without a fixture name; using builtin-xdr-lid-open")
            return .builtinXDRLidOpen
        }
        guard let fixture = DisplayFixture(rawValue: name) else {
            log.error("QA: unknown --qa-simulate fixture \(name, privacy: .public); using builtin-xdr-lid-open")
            return .builtinXDRLidOpen
        }
        return fixture
    }

    /// The context of a launch: the settings over `defaults`, and the real folders and Mac, or (simulated) temporary
    /// folders and the fixture's Mac.
    static func context(defaults: ShellDefaults, fixture: DisplayFixture?, time: any TimeSource) -> ShellContext {
        ShellContext(settings: SettingsStore(defaults: defaults.defaults), paths: fixture == nil ? .live : .temporary(),
                     machine: fixture?.machine ?? .current(), time: time, qaSuite: defaults.qaSuite)
    }

    /// The control's outlet on the real ports: the system's (notifyd, the app's preferences domain, Control Center),
    /// or a silent one when the launch keeps its settings in a QA suite (`QAHooks+Defaults`: such a run never writes
    /// the standard domain, and the control's token and snapshot live there).
    static func controlOutlet(for context: ShellContext) -> any ControlStateOutlet {
        context.qaSuite == nil ? SystemControlOutlet() : QuietControlOutlet()
    }

    /// The ports for this launch: the simulated ones whenever `--qa-simulate` is present (in any build; a Release
    /// build has refused the switch before this, see `refusedSwitches`), the real ones only without it.
    static func ports(for arguments: LaunchArguments, context: ShellContext) -> ShellPorts {
        ports(fixture: simulatedFixture(for: arguments), context: context)
    }

    /// The simulated ports over `fixture`, or the real ones for nil.
    static func ports(fixture: DisplayFixture?, context: ShellContext) -> ShellPorts {
        if let fixture { return simulatedPorts(fixture, context: context) }
        return livePorts(context)
    }

    /// Core fakes over `fixture`: nothing reaches a display. `hotKeys` registers the shortcuts (tests pass a recorder,
    /// so no test registers a system-wide hot key).
    static func simulatedPorts(_ fixture: DisplayFixture, context: ShellContext,
                               hotKeys registrar: any HotKeyRegistrar = CarbonHotKeyRegistrar()) -> ShellPorts {
        let time = context.time
        let headroom = ScriptedHeadroom(fixture: fixture, time: time)
        let directory = FakeDisplayDirectory(fixture: fixture)
        let signals = FakeSystemSignals()
        let fillLight = FillLightController(
            settings: context.settings, displays: directory, headroom: headroom, signals: signals,
            ownEDRSurfaces: context.ownEDRSurfaces, time: time, journal: context.journal, announcer: context.announcer,
            surfaces: SystemFillLightSurfaces(mode: .sdrStandIn, time: time))
        let hotKeys = HotKeyCenter(settings: context.settings, registrar: registrar)
        let updates = UpdateChecker(settings: context.settings, paths: context.paths)
        // The fakes record their history for tests; a QA run or a soak keeps only the newest records.
        let gamma = FakeGammaPort(fixture: fixture, time: time)
        gamma.recordLimit = qaRecordLimit
        let triggers = FakeTriggerFactory(headroom: headroom)
        triggers.recordLimit = qaRecordLimit
        return ShellPorts(gamma: gamma, headroom: headroom, displays: directory, triggers: triggers, signals: signals,
                          launchCheckSignals: signals, conflicts: FakeConflictProbe(), fillLight: fillLight,
                          shortcuts: hotKeys, hotKeys: hotKeys, updates: updates, loginItems: InMemoryLoginItem(),
                          controlOutlet: QuietControlOutlet(), readDisplays: { directory.displays },
                          profileHasVCGT: { _ in nil }, backlightMilliNits: { nil },
                          services: ServiceStack(fillLight: fillLight, hotKeys: hotKeys, updates: updates),
                          relays: [], fixture: fixture)
    }

    /// The real ports (see the file header). Never constructed in a test (lint `noWritesInHardwareTests`).
    static func livePorts(_ context: ShellContext) -> ShellPorts {
        let time = context.time
        let gamma = CoreGraphicsGamma()
        let directory = SystemDisplayDirectory(time: time, gamma: gamma)
        let headroom = SystemHeadroomPort(time: time)
        let triggers = SystemTriggerFactory(time: time, cacheDirectory: context.paths.caches)
        let conflicts = RunningAppsConflictProbe(catalog: ConflictCatalog.entries)
        let signals = SignalsMonitor(settings: context.settings, time: time, journal: context.journal,
                                     displays: directory, conflicts: conflicts)
        let relay = relayDisplayEvents(from: directory.addEventObserver) { [weak signals] event in signals?.post(event) }
        let fillLight = FillLightController(
            settings: context.settings, displays: directory, headroom: headroom, signals: signals,
            ownEDRSurfaces: context.ownEDRSurfaces, time: time, journal: context.journal, announcer: context.announcer,
            surfaces: SystemFillLightSurfaces(mode: .live, time: time))
        let hotKeys = HotKeyCenter(settings: context.settings)
        let updates = UpdateChecker(settings: context.settings, paths: context.paths)
        let launchCheckSignals = LaunchCheckSignals(base: signals, hasStarted: { [weak signals] in
            signals?.isStarted ?? false
        })
        return ShellPorts(gamma: gamma, headroom: headroom, displays: directory, triggers: triggers, signals: signals,
                          launchCheckSignals: launchCheckSignals, conflicts: conflicts, fillLight: fillLight,
                          shortcuts: hotKeys, hotKeys: hotKeys, updates: updates, loginItems: MainAppLoginItem(),
                          controlOutlet: controlOutlet(for: context),
                          readDisplays: { SystemDisplayDirectory.onlineDisplays() },
                          profileHasVCGT: { gamma.profileHasVCGT(of: $0) },
                          backlightMilliNits: { IORegistryFacts.read().builtIn?.backlightMilliNits },
                          services: ServiceStack(displays: directory, triggers: triggers, signals: signals,
                                                 fillLight: fillLight, hotKeys: hotKeys, updates: updates),
                          relays: [relay], fixture: nil)
    }

    /// §4.3, §7.1: Displays' events (`displayConfigurationBegan`, `displayRemoved`, `displaysReconfigured`,
    /// `screenParametersChanged`) go into Signals' event stream synchronously, so they reach the engine (and Fill
    /// Light) the way Signals' own events do: a removed display's windows are ordered out before the reconfiguration
    /// callback returns. Keep the token for the life of the launch.
    static func relayDisplayEvents(from source: (@escaping @MainActor (SystemEvent) -> Void) -> ObservationToken,
                                   to sink: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        source { event in sink(event) }
    }

    /// The hub, the ordered services and the safety net over `ports`. `scriptedStatus` (`--qa-state`) replaces the
    /// engine with a `PreviewBoostControl` showing that status, and Fill Light with a `PreviewFillLightControl` that is
    /// on when `scriptedFillLightOn` (no window shows; the state's settings are `QAHooks.scriptedState`'s).
    static func makeShell(_ context: ShellContext, ports: ShellPorts, scriptedStatus: BoostStatus? = nil,
                          scriptedFillLightOn: Bool = false) -> Shell {
        var stack = ports.services
        let boost: any BoostControl
        var engine: BoostEngine?
        let fillLight: any FillLightControl = scriptedStatus == nil ? ports.fillLight
            : PreviewFillLightControl(isOn: scriptedFillLightOn)
        if let scriptedStatus {
            boost = PreviewBoostControl(status: scriptedStatus, machine: context.machine)
        } else {
            let made = BoostEngine(settings: context.settings, machine: context.machine, time: context.time,
                                   journal: context.journal, ownEDRSurfaces: context.ownEDRSurfaces,
                                   displays: ports.displays, signals: ports.signals, gamma: ports.gamma,
                                   headroom: ports.headroom, triggers: ports.triggers, conflicts: ports.conflicts)
            made.useStrategyCache(at: context.paths.caches.appending(path: strategyCacheFileName))
            engine = made
            boost = made
        }
        stack.intents = ControlStateService(boost: boost, outlet: ports.controlOutlet)
        stack.boost = engine                                              // Boost starts last, stops first (D7)
        let services = OverbrightServices(settings: context.settings, paths: context.paths, machine: context.machine,
                                          time: context.time, journal: context.journal, announcer: context.announcer,
                                          ownEDRSurfaces: context.ownEDRSurfaces, displays: ports.displays,
                                          signals: ports.signals, boost: boost, fillLight: fillLight,
                                          shortcuts: ports.shortcuts, updates: ports.updates)
        ports.hotKeys?.onPress = { [weak boost] shortcut in
            guard let boost else { return }
            ShortcutActions.perform(shortcut, boost: boost, fillLight: fillLight)
        }
        let readDisplays = ports.readDisplays
        let rescue = LaunchRescue(gamma: ports.gamma, conflicts: ports.conflicts, signals: ports.launchCheckSignals,
                                  journal: context.journal, time: context.time,
                                  displays: { readDisplays().map(\.ref) }, settings: context.settings)
        rescue.onDeferredOutcome = { [weak engine] outcome in engine?.applyLaunchCheck(outcome) }
        let runner = ServiceRunner(stack: stack, time: context.time, journal: context.journal)
        let handlers = engine.map { engine in
            SignalHandlers(writer: engine.writer) { [runner] in await runner.stop(within: EngineTiming.quitTimeout) }
        }
        return Shell(services: services, ports: ports, stack: stack, runner: runner, rescue: rescue, engine: engine,
                     signalHandlers: handlers)
    }

    /// The launch work (§7.4): the launch check, then every service in order; its outcome reaches the engine right
    /// before the engine starts, when the directory lists the displays. A check skipped off the console (D27) runs
    /// again there when the session is on the console by then (`launchCheckBeforeBoost`).
    static func runLaunchWork(_ shell: Shell) async {
        let outcome = await shell.rescue.runLaunchCheck()
        log.info("launch check: \(String(describing: outcome), privacy: .public)")
        await shell.runner.start(beforeBoost: {
            let latest = await launchCheckBeforeBoost(shell, first: outcome)
            shell.engine?.applyLaunchCheck(latest)
        })
    }

    /// The outcome the engine gets as it starts: the newest one. The rescue runs a skipped check by itself on
    /// `sessionBecameActive`, but a return to the console between the skipped check and Signals' start posts nothing
    /// Signals hears (`SignalsMonitor` reads the session state when it starts, as no event), so that check would never
    /// run: a leftover table would only trip the engine (`foreignTableAtLaunch`) and the boost marker would stay. When
    /// the check was skipped, no deferred check is under way and Signals now says the session is on the console, it
    /// runs here.
    static func launchCheckBeforeBoost(_ shell: Shell, first: RescueOutcome) async -> RescueOutcome {
        let rescue = shell.rescue
        let latest = rescue.lastOutcome ?? first
        guard latest == .skippedNotOnConsole, rescue.deferredCheck == nil,
              shell.ports.signals.snapshot.isSessionActive else { return latest }
        let outcome = await rescue.runLaunchCheck()
        log.info("launch check, on the console by the engine's start: \(String(describing: outcome), privacy: .public)")
        return outcome
    }
}
