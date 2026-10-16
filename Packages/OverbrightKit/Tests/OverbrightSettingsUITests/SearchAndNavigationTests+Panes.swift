// OverbrightSettingsUITests/SearchAndNavigationTests+Panes.swift — the search over the panes WP11 filled (ARCHITECTURE.md
// §10.13 acceptance: "search finds every row by its label and keywords ("HDR", "XDR", "nits", "brighter", "dim",
// "battery", "shortcut", "camera", "login", "quit")"), next to WP0b's suite of the search machinery.
import Foundation
import OverbrightCore
import OverbrightDesign
import Testing
@testable import OverbrightSettingsUI

extension SearchAndNavigationTests {
    /// The real index of a rich setup: two classified displays, the schedule on, an OLED display known.
    private func paneIndex() -> (SettingsSearchIndex, [SettingsRowInfo]) {
        let services = PaneValues.richServices()
        let rows = SettingsPaneCatalog.rows(services: services)
        return (SettingsSearchIndex(panes: SettingsPane.all, rows: rows, keywords: KnownPaneKeywords.all), rows)
    }

    /// Every row is found by its own label and by each of its keywords.
    @Test func everyRowIsFoundByItsLabelAndItsKeywords() {
        let (index, rows) = paneIndex()
        #expect(rows.count >= 60)
        for row in rows {
            #expect(index.search(row.title).rows.contains(row), "\(row.id) by its label «\(row.title)»")
            for keyword in row.keywords {
                #expect(index.search(keyword).rows.contains(row), "\(row.id) by «\(keyword)»")
            }
        }
    }

    /// DESIGN.md §7.2's search words find rows, not only panes, in the panes that hold their subject.
    @Test func designKeywordsFindRows() {
        let (index, _) = paneIndex()
        let expected: [(String, SettingsPaneID)] = [
            ("HDR", .displays), ("XDR", .displays), ("nits", .displays), ("brighter", .displays), ("dim", .displays),
            ("battery", .automations), ("shortcut", .shortcuts), ("camera", .fillLight), ("login", .general),
            ("quit", .general), ("OLED", .displays), ("flicker", .advanced), ("colors", .advanced),
        ]
        for (query, pane) in expected {
            #expect(index.search(query).rows.contains { $0.pane == pane }, "«\(query)» finds no row in \(pane)")
        }
    }

    /// A display's rows carry its name: "<name> limit" finds that display's Limit and no other.
    @Test func aDisplaysNameNarrowsItsRows() throws {
        let (index, _) = paneIndex()
        let hits = index.search("MPG322UX limit").rows
        #expect(hits.map(\.id) == ["displays.\(DisplayFixture.Keys.mpg322ux.rawValue).limit"])
        #expect(index.search("Limit").rows.count == 2)                             // one per display
    }

    /// The words of one row are the words the pane draws: the Limit row's choices are Design's names.
    @Test func keywordsAreTheShownNames() {
        let limit = DisplaysRows.limit(DisplayFixture.Keys.builtIn, name: "Built-in")
        #expect(limit.keywords.contains(CapMode.safe.localizedName()) && limit.keywords.contains(CapMode.peak.localizedName()))
    }
}
