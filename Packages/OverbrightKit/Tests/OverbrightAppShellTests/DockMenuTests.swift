// OverbrightAppShellTests/DockMenuTests.swift — the Dock icon's menu as the app wires it (DESIGN.md §4.4;
// ARCHITECTURE.md §7.4 "Back to Standard … the Dock menu", §10.15): over the real engine and the simulated ports, its
// rows follow the engine, Turn On turns the master on, Dim All dims, Back to Standard turns it off at once, and
// Settings… opens Settings. The app delegate returns this menu from `applicationDockMenu(_:)` once its controllers
// exist (`ReopenTests` checks it is nil before).
import AppKit
import OverbrightCore
import OverbrightPanelUI
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct DockMenuTests {
    private func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "---" : $0.title } }

    private func run(_ title: String, in menu: NSMenu) throws {
        let item = try #require(menu.items.first { $0.title == title })
        ActionMenuItem.run(item)
    }

    @Test func theDockMenuDrivesTheRealEngine() async throws {
        let time = ManualTimeSource()
        let shell = TestShell.shell(context: TestShell.context(time: time))
        let app = PreviewAppControl()
        shell.services.app = app
        await CompositionRoot.runLaunchWork(shell)
        let dock = DockMenuController(services: shell.services)
        let boost = shell.services.boost

        #expect(titles(dock.menu()) == ["Turn On Overbright", "Dim All Displays", "Back to Standard", "---", "Settings…"])
        try run("Turn On Overbright", in: dock.menu())
        #expect(boost.status.isOn)
        #expect(titles(dock.menu()).first == "Turn Off Overbright")

        try run("Dim All Displays", in: dock.menu())
        for _ in 0..<40 { await time.advance(by: .milliseconds(10)) }
        #expect(boost.status.displays.allSatisfy { $0.appliedGain < 1 })
        #expect(titles(dock.menu())[1] == "Stop Dimming")

        try run("Back to Standard", in: dock.menu())
        for _ in 0..<40 { await time.advance(by: .milliseconds(10)) }
        #expect(!boost.status.isOn)
        #expect(boost.status.displays.allSatisfy { $0.appliedGain == 1 })

        try run("Settings…", in: dock.menu())
        #expect(app.calls == ["openSettings(-)"])
    }

    @Test func theDockIconFollowsShowInDock() {
        #expect(DockMenuController.activationPolicy(showsDockIcon: GeneralSettings.showsDockIcon.defaultValue)
            == .accessory)
        #expect(DockMenuController.activationPolicy(showsDockIcon: true) == .regular)
    }
}
