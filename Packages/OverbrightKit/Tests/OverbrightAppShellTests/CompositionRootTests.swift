// OverbrightAppShellTests/CompositionRootTests.swift — the composition root (ARCHITECTURE.md §3.9, §7.4, §10.0, D7,
// D24): building the services touches nothing (`constructingServicesTouchesNoHardware`, the successor of Cranny's
// `registersEveryContributionWithoutSideEffects`), Boost starts last, `--qa-simulate` never yields a real port (with
// or without a fixture name), the single-instance exemption follows the wiring, and a Release build refuses the
// Debug-only switches. No test here constructs the real ports (lint `noWritesInHardwareTests`).
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightIntents
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct CompositionRootTests {
    private func shell(ports: ShellPorts? = nil, scriptedStatus: BoostStatus? = nil) -> Shell {
        let context = TestShell.context()
        return CompositionRoot.makeShell(context, ports: ports ?? TestShell.ports(context: context),
                                         scriptedStatus: scriptedStatus)
    }

    /// Building the hub, the engine, the launch rescue, the app control and every shell controller calls no port:
    /// every port is a trap that records any call. Only `start()` may touch them (shown at the end, so the traps are
    /// not vacuous).
    @Test func constructingServicesTouchesNoHardware() async {
        let log = TrapLog()
        let gamma = TrapGammaPort()
        let shell = shell(ports: .traps(log: log, gamma: gamma))
        let services = shell.services
        let control = ShellAppControl(settings: services.settings,
                                      loginItems: LoginItemController(service: shell.ports.loginItems))
        services.app = control
        let statusItem = StatusItemController(services: services)
        control.connect(ShellAppControl.Controllers(
            icon: StatusIconPresence(services: services, statusItem: statusItem), panel: PanelController(services: services),
            settings: SettingsWindowController(services: services), welcome: WelcomeWindowController(services: services),
            help: HelpWindowController(services: services), calibration: CalibrationWindowController(services: services),
            selfTest: SelfTestSheetPresenter(services: services), diagnostics: { nil }))
        _ = HUDController(services: services)
        _ = LowLevelPromptController(services: services)
        _ = DockMenuController(services: services)

        #expect(log.calls.isEmpty, "touched before start(): \(log.calls)")
        #expect(gamma.reads.isEmpty && gamma.writes.isEmpty)
        #expect(statusItem.button == nil)                                     // nothing in the menu bar yet
        #expect(services.boost.status == .initial)

        for service in shell.lifecycle { await service.start() }
        #expect(log.calls.contains("directory.displays"))                    // the engine reads only when started
        #expect(gamma.writes.isEmpty)
    }

    /// Boost starts last and stops first (D7, D23).
    @Test func boostStartsLast() {
        let shell = shell()
        #expect(shell.lifecycle.last is BoostEngine)
        #expect(shell.services.boost is BoostEngine)
        #expect(shell.engine === shell.services.boost as? BoostEngine)
        #expect(shell.signalHandlers != nil)
    }

    /// `--qa-state` swaps the engine for a `PreviewBoostControl` with that status (and no engine in the lifecycle).
    @Test func scriptedStatusReplacesTheEngine() {
        let status = BoostStatus(isOn: true, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: [], banner: nil,
                                 symbol: .on)
        let shell = shell(scriptedStatus: status)
        #expect(shell.services.boost.status == status)
        #expect(!shell.lifecycle.contains { $0 is BoostEngine })
        #expect(shell.engine == nil && shell.signalHandlers == nil)
    }

    /// A Debug run with its own `--qa-defaults-suite` on the real ports (the owner's hardware session) keeps the
    /// control's token and snapshot out of the app's preferences domain: its outlet is silent (QAHooks+Defaults'
    /// promise). Only a launch on the standard domain publishes. Decided on the context alone: no real port is built.
    @Test func aQASuiteKeepsTheControlChannelSilent() {
        func context(_ suite: String?) -> ShellContext {
            CompositionRoot.context(defaults: ShellDefaults(defaults: InMemoryDefaults(), qaSuite: suite),
                                    fixture: .builtinXDRLidOpen, time: ManualTimeSource())
        }
        #expect(context("app.overbright.Overbright.hw").qaSuite == "app.overbright.Overbright.hw")
        #expect(CompositionRoot.controlOutlet(for: context("app.overbright.Overbright.hw")) is QuietControlOutlet)
        #expect(CompositionRoot.controlOutlet(for: context("memory")) is QuietControlOutlet)
        #expect(CompositionRoot.controlOutlet(for: context(nil)) is SystemControlOutlet)
    }

    /// `--qa-state` also swaps Fill Light for a preview that is on when the state says so (no window ever shows).
    @Test func aScriptedStateHasAFillLightPreview() {
        let context = TestShell.context()
        let ports = TestShell.ports(context: context)
        let on = CompositionRoot.makeShell(context, ports: ports, scriptedStatus: .initial, scriptedFillLightOn: true)
        #expect(on.services.fillLight is PreviewFillLightControl && on.services.fillLight.isOn)
        #expect(!CompositionRoot.makeShell(context, ports: ports, scriptedStatus: .initial).services.fillLight.isOn)
        #expect(!(shell().services.fillLight is PreviewFillLightControl))              // the engine's run: the real one
    }

    /// D24: `--qa-simulate` wires only Core fakes, whatever follows it: a known fixture, an unknown name, another
    /// switch or nothing at all (the switch last) all get a fixture, never the real ports.
    @Test func simulationNeverUsesRealPorts() {
        for arguments in [["Overbright", "--qa-simulate", "builtin-xdr-lid-open"],
                          ["Overbright", "--qa-simulate", "mpg322ux-hdr-on"],
                          ["Overbright", "--qa-simulate", "no-such-fixture"],
                          ["Overbright", "--off", "--qa-simulate"],
                          ["Overbright", "--qa-simulate", "--off"],
                          ["Overbright", "--qa-simulate", "--qa-defaults-suite", "app.overbright.Overbright.dev"]] {
            let fixture = CompositionRoot.simulatedFixture(for: LaunchArguments(arguments))
            #expect(fixture != nil, "\(arguments)")
            let ports = TestShell.ports(fixture ?? .builtinXDRLidOpen, context: TestShell.context())
            #expect(ports.gamma is FakeGammaPort, "\(arguments)")
            #expect(ports.headroom is ScriptedHeadroom)
            #expect(ports.displays is FakeDisplayDirectory)
            #expect(ports.triggers is FakeTriggerFactory)
            #expect(ports.signals is FakeSystemSignals && ports.conflicts is FakeConflictProbe)
            #expect(ports.loginItems is InMemoryLoginItem && !ports.controlOutlet.isControlInstalled)
            #expect(ports.fixture != nil, "\(arguments)")
            #expect(ports.services.displays == nil && ports.services.triggers == nil && ports.services.signals == nil)
        }
        let fixture = CompositionRoot.simulatedFixture(for: LaunchArguments(["Overbright", "--qa-simulate",
                                                                              "mpg322ux-hdr-on"]))
        #expect(fixture == .mpg322uxHDROn)
    }

    /// The wiring decision, checked without constructing any port: a missing or unknown name falls back to
    /// `builtin-xdr-lid-open`, and only a launch without the switch gets the real ports (nil).
    @Test func simulatedFixtureFollowsTheSwitchNotTheName() {
        func fixture(_ arguments: [String]) -> DisplayFixture? {
            CompositionRoot.simulatedFixture(for: LaunchArguments(["Overbright"] + arguments))
        }
        #expect(fixture(["--qa-simulate", "mpg322ux-hdr-on"]) == .mpg322uxHDROn)
        #expect(fixture(["--off", "--qa-simulate"]) == .builtinXDRLidOpen)
        #expect(fixture(["--qa-simulate", "--off"]) == .builtinXDRLidOpen)
        #expect(fixture(["--qa-simulate", "no-such-fixture"]) == .builtinXDRLidOpen)
        #expect(fixture([]) == nil)
        #expect(fixture(["--off", "--qa-defaults-suite", "app.overbright.Overbright.dev"]) == nil)
        #expect(fixture(["--diagnostics", "-"]) == nil)
    }

    /// D27 follows the wiring, not the arguments: a launch wired to the simulated ports or a command-line mode skips
    /// the single-instance check; a launch wired to the real ports never does, even with `--qa-simulate` present.
    /// No test constructs the real ports (D24): `ShellPorts.traps` stands in for them (no fixture).
    @Test func singleInstanceExemptionFollowsTheWiring() {
        let simulated = TestShell.ports(context: TestShell.context())
        let real = ShellPorts.traps(log: TrapLog(), gamma: TrapGammaPort())
        let qa = LaunchArguments(["Overbright", "--qa-simulate", "builtin-xdr-lid-open"])
        #expect(real.fixture == nil)
        #expect(CompositionRoot.skipsSingleInstanceCheck(qa, ports: simulated))
        #expect(!CompositionRoot.skipsSingleInstanceCheck(qa, ports: real))
        #expect(!CompositionRoot.skipsSingleInstanceCheck(LaunchArguments(["Overbright"]), ports: real))
        #expect(!CompositionRoot.skipsSingleInstanceCheck(LaunchArguments(["Overbright", "--off"]), ports: real))
        for mode in [["--diagnostics", "-"], ["--monitor", "2"], ["--restore-gamma"]] {
            let arguments = LaunchArguments(["Overbright"] + mode)
            #expect(CompositionRoot.skipsSingleInstanceCheck(arguments, ports: real), "\(mode)")
        }
    }

    /// §8.5: a Release build refuses to start with a Debug-only switch rather than ignore it and wire the real ports;
    /// a Debug build refuses nothing, and no build refuses the Release switches.
    @Test func releaseBuildRefusesDebugOnlySwitches() {
        let qa = LaunchArguments(["Overbright", "--off", "--qa-simulate", "builtin-xdr-lid-open", "--qa-defaults-suite",
                                  "app.overbright.Overbright.dev"])
        #expect(CompositionRoot.refusedSwitches(qa, debugBuild: false) == ["--qa-simulate", "--qa-defaults-suite"])
        #expect(CompositionRoot.refusedSwitches(qa, debugBuild: true).isEmpty)
        let release = LaunchArguments(["Overbright", "--off", "--diagnostics", "-"])
        #expect(CompositionRoot.refusedSwitches(release, debugBuild: false).isEmpty)
        #if DEBUG
        #expect(CompositionRoot.isDebugBuild && CompositionRoot.refusedSwitches(qa).isEmpty)
        #else
        #expect(!CompositionRoot.isDebugBuild && !CompositionRoot.refusedSwitches(qa).isEmpty)
        #endif
    }

    /// Every fixture of §3.9 wires and reads back its own displays.
    @Test func everyFixtureWires() {
        for fixture in DisplayFixture.allCases {
            let ports = TestShell.ports(fixture, context: TestShell.context(fixture: fixture))
            #expect(ports.readDisplays().map(\.ref.key) == fixture.displays.map(\.key).sorted { a, b in
                let builtIn = Set(fixture.displays.filter(\.facts.isBuiltIn).map(\.key))
                return builtIn.contains(a) != builtIn.contains(b) ? builtIn.contains(a) : a < b
            }, "\(fixture)")
        }
    }
}
