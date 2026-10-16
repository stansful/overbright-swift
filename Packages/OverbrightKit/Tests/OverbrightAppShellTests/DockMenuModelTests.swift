// OverbrightAppShellTests/DockMenuModelTests.swift — the optional Dock icon (DESIGN.md §4.4): Turn On / Turn Off
// Overbright, Dim All Displays / Stop Dimming, Back to Standard and Settings…, acting through the engine; the Dock icon
// follows General ▸ Show in Dock (`.regular` with it, `.accessory` without). WP13 wires `applicationDockMenu(_:)` and
// keeps its own `DockMenuTests` for that wiring.
import AppKit
import OverbrightCore
import OverbrightPanelUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct DockMenuModelTests {
    @Test func theRowsFollowTheState() throws {
        let off = try #require(ScriptedStatuses.status(named: "off"))
        #expect(DockMenuRow.rows(for: off) == [.master(isOn: false), .dimAll(isDimmed: false), .backToStandard, .separator,
                                               .settings])
        #expect(DockMenuRow.rows(for: off).map(\.title)
            == ["Turn On Overbright", "Dim All Displays", "Back to Standard", "---", "Settings…"])
        let dimmed = try #require(ScriptedStatuses.status(named: "keep-level"))
        #expect(DockMenuRow.rows(for: dimmed).first == .master(isOn: true))
        #expect(DockMenuRow.rows(for: dimmed)[1] == .dimAll(isDimmed: true))
        #expect(DockMenuRow.dimAll(isDimmed: true).title == "Stop Dimming")
    }

    @Test func theMenuActsThroughTheEngine() throws {
        let services = try #require(ScriptedStatuses.services(named: "boosting"))
        let menu = DockMenuController(services: services).menu()
        #expect(menu.items.map { $0.isSeparatorItem ? "---" : $0.title }
            == ["Turn Off Overbright", "Dim All Displays", "Back to Standard", "---", "Settings…"])
        for item in menu.items where !item.isSeparatorItem { ActionMenuItem.run(item) }
        let boost = try #require(services.boost as? PreviewBoostControl)
        #expect(boost.calls == ["setOn(false,menu)", "toggleDim(menu)", "returnToStandard(menu)"])
        let app = try #require(services.app as? PreviewAppControl)
        #expect(app.calls == ["openSettings(-)"])
    }

    @Test func theDockIconFollowsTheSetting() {
        #expect(DockMenuController.activationPolicy(showsDockIcon: true) == .regular)
        #expect(DockMenuController.activationPolicy(showsDockIcon: false) == .accessory)
        #expect(GeneralSettings.showsDockIcon.defaultValue == false)
    }
}
