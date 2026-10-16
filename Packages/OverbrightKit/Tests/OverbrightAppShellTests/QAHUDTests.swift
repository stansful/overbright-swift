// OverbrightAppShellTests/QAHUDTests.swift — `--qa-hud <level>` (ARCHITECTURE.md §8.5): under `--qa-simulate` it sets
// every display to that level as a shortcut would, so the HUD shows it for real; on the real ports (a Debug hardware
// session without `--qa-simulate`) it only shows the HUD's generic level change and sets no display. No test here
// constructs the real ports: the trap ports record any call.
#if DEBUG
import OverbrightCore
import OverbrightDesign
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct QAHUDTests {
    /// The hooks' targets over `shell`, with a HUD that orders no window in.
    private func targets(_ shell: Shell) -> QAHooks.Targets {
        let services = shell.services
        let control = ShellAppControl(settings: services.settings,
                                      loginItems: LoginItemController(service: shell.ports.loginItems))
        let hud = HUDController(services: services, slot: HUDSlot()) { change, _ in
            HUDText(symbol: .sunMax, displayName: nil, value: "v\(change.sequence)", reason: nil,
                    announcement: "change \(change.sequence)")
        }
        hud.presentsWindows = false
        return QAHooks.Targets(shell: shell, appControl: control, welcome: WelcomeWindowController(services: services),
                               statusItem: StatusItemController(services: services), hud: hud)
    }

    @Test func onlyTheSimulatedPortsTakeALevel() {
        let simulated = TestShell.shell().ports
        #expect(QAHooks.hudLevel("max", ports: simulated) == LevelPreset.max.position)
        #expect(QAHooks.hudLevel("-0.5", ports: simulated) == LevelPosition(-0.5))
        #expect(QAHooks.hudLevel("loud", ports: simulated) == nil)
        let real = ShellPorts.traps(log: TrapLog(), gamma: TrapGammaPort())
        #expect(QAHooks.hudLevel("max", ports: real) == nil)
        #expect(QAHooks.hudLevel("-0.5", ports: real) == nil)
    }

    /// On the real ports the switch opens the HUD and touches nothing: no port call, no level stored.
    @Test func onTheRealPortsTheHUDOpensAndNoDisplayIsSet() {
        let log = TrapLog()
        let gamma = TrapGammaPort()
        let shell = CompositionRoot.makeShell(TestShell.context(), ports: .traps(log: log, gamma: gamma),
                                              scriptedStatus: nil)
        let targets = targets(shell)
        let before = shell.services.settings[DisplaySettings.perDisplay]
        QAHooks.showHUD("max", targets: targets)
        #expect(log.calls.isEmpty, "touched: \(log.calls)")
        #expect(gamma.writes.isEmpty)
        #expect(shell.services.settings[DisplaySettings.perDisplay] == before)
        #expect(targets.hud.showCount == 1)
    }

    /// Under `--qa-simulate` the level is set on every display, as a shortcut would.
    @Test func overTheSimulatedPortsEveryDisplayTakesTheLevel() {
        let shell = TestShell.shell()
        let targets = targets(shell)
        QAHooks.showHUD("max", targets: targets)
        let stored = shell.services.settings[DisplaySettings.perDisplay]
        #expect(stored[DisplayFixture.Keys.builtIn]?.level == LevelPreset.max.position)
        #expect(targets.hud.showCount == 0)                                   // the engine's change shows, once started
    }
}
#endif
