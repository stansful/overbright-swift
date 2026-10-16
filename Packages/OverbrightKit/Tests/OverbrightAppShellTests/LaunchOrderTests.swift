// OverbrightAppShellTests/LaunchOrderTests.swift — the launch order of ARCHITECTURE.md §7.4 (`LaunchSequence`, the
// app delegate's only path): the Release refusal first, then the hub, then the command-line modes (which start
// nothing and write nothing), the single instance (D27), the move offer, the settings upgrade, the controllers, the
// launch work, the QA hooks and the launch UI.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct LaunchOrderTests {
    /// Effects that record what ran, in order.
    private final class Recorder {
        var calls: [String] = []
        var refused: [String] = []
        var runsCommandLineMode = false
        var handsOver = false

        func effects() -> LaunchSequence.Effects {
            LaunchSequence.Effects(
                refusedSwitches: { self.calls.append("check switches"); return self.refused },
                refuse: { _ in self.calls.append("refuse") },
                makeShell: { self.calls.append("hub"); return TestShell.shell() },
                runCommandLineMode: { _ in self.calls.append("command-line mode"); return self.runsCommandLineMode },
                handOver: { _ in self.calls.append("single instance"); return self.handsOver },
                offerMove: { _ in self.calls.append("move") },
                upgradeSettings: { _ in self.calls.append("upgrade") },
                buildControllers: { _ in self.calls.append("controllers") },
                startLaunchWork: { _ in self.calls.append("launch work") },
                applyQAHooks: { _ in self.calls.append("qa hooks") },
                showLaunchUI: { _ in self.calls.append("launch UI") })
        }
    }

    @Test func theStepsFollowTheArchitecture() {
        #expect(LaunchStep.allCases.map(\.rawValue)
            == ["refuseDebugSwitches", "servicesHub", "commandLineModes", "singleInstance", "moveToApplications",
                "settingsUpgrade", "controllers", "launchWork", "qaHooks", "launchUI"])
    }

    @Test func anOrdinaryLaunchRunsEveryStepInOrder() {
        let recorder = Recorder()
        var steps: [LaunchStep] = []
        var effects = recorder.effects()
        effects.willRun = { steps.append($0) }
        #expect(LaunchSequence.run(effects) != nil)
        #expect(recorder.calls == ["check switches", "hub", "command-line mode", "single instance", "move", "upgrade",
                                   "controllers", "launch work", "qa hooks", "launch UI"])
        #expect(steps == LaunchStep.allCases)
    }

    /// §8.5: a Release build given a Debug-only switch stops before anything else, so nothing is built or written.
    @Test func aRefusedSwitchStopsBeforeTheHub() {
        let recorder = Recorder()
        recorder.refused = ["--qa-simulate"]
        #expect(LaunchSequence.run(recorder.effects()) == nil)
        #expect(recorder.calls == ["check switches", "refuse"])
    }

    /// `--diagnostics`, `--monitor` and `--restore-gamma` run before the single-instance check and quit there: no
    /// settings upgrade, no controller, no service (D24: diagnostics writes nothing).
    @Test func aCommandLineModeStartsNothing() {
        let recorder = Recorder()
        recorder.runsCommandLineMode = true
        #expect(LaunchSequence.run(recorder.effects()) == nil)
        #expect(recorder.calls == ["check switches", "hub", "command-line mode"])
    }

    /// D27: a second instance hands over before it offers a move, upgrades settings or builds a window.
    @Test func aSecondInstanceHandsOverBeforeAnythingElse() {
        let recorder = Recorder()
        recorder.handsOver = true
        #expect(LaunchSequence.run(recorder.effects()) == nil)
        #expect(recorder.calls == ["check switches", "hub", "command-line mode", "single instance"])
    }

    /// The single-instance exemption follows the wiring: a launch wired to the simulated ports skips it; a CLI mode
    /// skips it whatever the ports.
    @Test func theSingleInstanceCheckFollowsTheWiring() {
        let shell = TestShell.shell()
        #expect(CompositionRoot.skipsSingleInstanceCheck(LaunchArguments(["Overbright"]), ports: shell.ports))
        let real = ShellPorts.traps(log: TrapLog(), gamma: TrapGammaPort())
        #expect(!CompositionRoot.skipsSingleInstanceCheck(LaunchArguments(["Overbright"]), ports: real))
        #expect(CompositionRoot.skipsSingleInstanceCheck(LaunchArguments(["Overbright", "--restore-gamma"]), ports: real))
    }
}
