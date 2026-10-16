// OverbrightAppShellTests/CompositionRootTests.swift — the composition root (ARCHITECTURE.md §3.9, §7.4, §10.0, D7,
// D24): building the services touches nothing (`constructingServicesTouchesNoHardware`, the successor of Cranny's
// `registersEveryContributionWithoutSideEffects`), Boost starts last, and `--qa-simulate` never yields a real port.
import Foundation
import OverbrightBoost
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct CompositionRootTests {
    private func shell(ports: ShellPorts, scriptedStatus: BoostStatus? = nil) -> Shell {
        CompositionRoot.makeShell(settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(),
                                  machine: DisplayFixture.ownerMachine, time: ManualTimeSource(), ports: ports,
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
        let control = ShellAppControl(settings: services.settings)
        services.app = control
        let statusItem = StatusItemController(services: services)
        control.connect(ShellAppControl.Controllers(
            statusItem: statusItem, panel: PanelController(services: services),
            settings: SettingsWindowController(services: services), welcome: WelcomeWindowController(services: services),
            help: HelpWindowController(services: services), calibration: CalibrationWindowController(services: services),
            selfTest: SelfTestSheetPresenter(services: services), diagnostics: { nil }))
        _ = HUDController(services: services)
        _ = LowLevelPromptController(services: services)

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
        let shell = shell(ports: CompositionRoot.simulatedPorts(.builtinXDRLidOpen, time: ManualTimeSource()))
        #expect(shell.lifecycle.last is BoostEngine)
        #expect(shell.services.boost is BoostEngine)
    }

    /// `--qa-state` swaps the engine for a `PreviewBoostControl` with that status (and no engine in the lifecycle).
    @Test func scriptedStatusReplacesTheEngine() {
        let status = BoostStatus(isOn: true, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: [], banner: nil,
                                 symbol: .on)
        let shell = shell(ports: CompositionRoot.simulatedPorts(.builtinXDRLidOpen, time: ManualTimeSource()),
                          scriptedStatus: status)
        #expect(shell.services.boost.status == status)
        #expect(!shell.lifecycle.contains { $0 is BoostEngine })
    }

    /// D24: `--qa-simulate` wires only Core fakes, whatever the fixture name (an unknown one falls back to a fixture,
    /// never to the real ports).
    @Test func simulationNeverUsesRealPorts() {
        for arguments in [["Overbright", "--qa-simulate", "builtin-xdr-lid-open"],
                          ["Overbright", "--qa-simulate", "mpg322ux-hdr-on"],
                          ["Overbright", "--qa-simulate", "no-such-fixture"]] {
            let ports = CompositionRoot.ports(for: LaunchArguments(arguments), time: ManualTimeSource())
            #expect(ports.gamma is FakeGammaPort, "\(arguments)")
            #expect(ports.headroom is ScriptedHeadroom)
            #expect(ports.displays is FakeDisplayDirectory)
            #expect(ports.triggers is FakeTriggerFactory)
            #expect(ports.fixture != nil)
            #expect(ports.lifecycle.isEmpty)
        }
        let fixture = CompositionRoot.ports(for: LaunchArguments(["Overbright", "--qa-simulate", "mpg322ux-hdr-on"]),
                                            time: ManualTimeSource()).fixture
        #expect(fixture == .mpg322uxHDROn)
    }

    /// Every fixture of §3.9 wires and reads back its own displays.
    @Test func everyFixtureWires() {
        for fixture in DisplayFixture.allCases {
            let ports = CompositionRoot.simulatedPorts(fixture, time: ManualTimeSource())
            #expect(ports.readDisplays().map(\.ref.key) == fixture.displays.map(\.key).sorted { a, b in
                let builtIn = Set(fixture.displays.filter(\.facts.isBuiltIn).map(\.key))
                return builtIn.contains(a) != builtIn.contains(b) ? builtIn.contains(a) : a < b
            }, "\(fixture)")
        }
    }
}
