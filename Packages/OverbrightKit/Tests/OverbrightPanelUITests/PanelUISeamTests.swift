// OverbrightPanelUITests/PanelUISeamTests.swift — the PanelUI seam (ARCHITECTURE.md §10.0): the card, Help and the
// scripted statuses the shell's `--qa-state` reads. WP10 adds the gallery of DESIGN.md §5.13 and its snapshots.
import OverbrightCore
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelUISeamTests {
    @Test func everyScriptedNameResolves() throws {
        #expect(!ScriptedStatuses.names.isEmpty)
        for name in ScriptedStatuses.names {
            let status = try #require(ScriptedStatuses.status(named: name), "\(name)")
            #expect(status.isReady && !status.displays.isEmpty)
        }
        #expect(ScriptedStatuses.status(named: "no-such-state") == nil)
    }

    @Test func theCardAndHelpBuild() throws {
        let services = OverbrightServices.preview()
        let status = try #require(ScriptedStatuses.status(named: "off")?.displays.first)
        _ = DisplayCardView(status: status, isMasterOn: false, services: services)
        _ = HelpView(anchor: "no-extra-range")
    }
}
