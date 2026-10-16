// OverbrightSettingsUITests/UndoResetTests.swift — the three resets over the filled panes (DESIGN.md §7.2, §7.8, §12.4,
// §12.9): Reset to Default of one row touches only that row; "Reset ‹Pane›…" returns every value row of that pane to
// its default and no other pane's (Displays' includes display calibration); Reset All returns every row of every pane
// to its default, and Undo Reset brings every changed value back until the Settings window closes.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct UndoResetTests {
    /// Changes every value row of `services` that the test table knows; returns the ids changed.
    @discardableResult
    private func changeEverything(_ services: OverbrightServices) -> [String] {
        let ids = PaneValues.values(services).map(\.info.id).filter { !$0.hasPrefix("automations.schedule") }
        for id in ids { PaneValues.change(id, in: services) }
        services.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 600, endMinute: 1320)
        return ids
    }

    /// The ids of every value row that is not at its default.
    private func changedRows(_ services: OverbrightServices) -> Set<String> {
        Set(PaneValues.values(services).filter { !$0.isDefault() }.map(\.info.id))
    }

    @Test func resetToDefaultTouchesOnlyItsRow() throws {
        let services = PaneValues.richServices()
        changeEverything(services)
        let before = changedRows(services)
        let limit = "displays.\(DisplayFixture.Keys.builtIn.rawValue).limit"
        let value = try #require(PaneValues.values(services).first { $0.info.id == limit })
        value.reset()
        #expect(changedRows(services) == before.subtracting([limit]))
    }

    @Test(arguments: [SettingsPaneID.general, .displays, .automations, .shortcuts, .fillLight, .advanced])
    func resettingAPaneResetsItsRowsAndNoOthers(pane: SettingsPaneID) {
        let services = PaneValues.richServices()
        changeEverything(services)
        let before = changedRows(services)
        #expect(before.contains { $0.hasPrefix(pane.rawValue + ".") })
        PaneReset.reset(SettingsPane.pane(pane).namespaces, settings: services.settings)
        let after = changedRows(services)
        let ownLeft = after.filter { $0.hasPrefix(pane.rawValue + ".") }
        // Advanced's trigger methods live with the displays' preferences but follow the pane that shows them:
        // Reset Advanced… clears them, Reset Displays… keeps them (WP13).
        #expect(ownLeft.isEmpty, "\(pane): rows still changed after its reset: \(ownLeft)")
        let others = before.filter { !$0.hasPrefix(pane.rawValue + ".") }
        #expect(others.isSubset(of: after), "\(pane): its reset changed other panes: \(others.subtracting(after))")
    }

    @Test func resettingDisplaysIncludesCalibration() {
        let services = PaneValues.richServices()
        let editor = DisplayPreferencesEditor(settings: services.settings)
        editor.update(DisplayFixture.Keys.builtIn, name: "Built-in") { $0.calibration = FakeCalibrationSession.record(.linear) }
        PaneReset.reset(SettingsPane.pane(.displays).namespaces, settings: services.settings)
        #expect(editor.preferences(of: DisplayFixture.Keys.builtIn).calibration == nil)
        #expect(PaneFooter.message(for: .pane(.displays)) != PaneFooter.message(for: .pane(.automations)))
    }

    @Test func resetAllResetsEveryRowAndUndoBringsEveryValueBack() throws {
        let services = PaneValues.richServices()
        let app = try #require(services.app as? StoringAppControl)
        changeEverything(services)
        let changed = changedRows(services)
        #expect(changed.count >= 35)
        let snapshot = Dictionary(uniqueKeysWithValues: PaneValues.values(services).map { ($0.info.id, $0.isDefault()) })
        let controller = ResetAllController(services: services, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        controller.resetAll()
        #expect(app.calls.last == "resetAllSettings")
        #expect(changedRows(services).isEmpty, "rows not at their default after Reset All: \(changedRows(services))")
        #expect(controller.canUndo)
        controller.undo()
        #expect(changedRows(services) == changed)
        let restored = Dictionary(uniqueKeysWithValues: PaneValues.values(services).map { ($0.info.id, $0.isDefault()) })
        #expect(restored == snapshot)
        #expect(!controller.canUndo)
    }

    /// Undo Reset stays in Advanced until the Settings window closes, the banner or not.
    @Test func undoResetLastsUntilTheWindowCloses() {
        let services = PaneValues.richServices()
        changeEverything(services)
        let session = SettingsSession(services: services)
        session.resetAll.resetAll()
        session.resetAll.dismissBanner()
        #expect(session.canUndoReset)
        session.windowDidClose()
        #expect(!session.canUndoReset)
        #expect(changedRows(services).isEmpty)                                     // the reset stays
    }
}
