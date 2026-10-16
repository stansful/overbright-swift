// OverbrightSettingsUITests/SearchAndNavigationTests.swift — the Settings search and deep links (DESIGN.md §7.2:
// "Search matches pane names, row labels and keywords; a result opens the pane, scrolls to the row and highlights it";
// "Deep links pane#row serve chips, banners, the menu and Help"). Ported from Cranny's SearchAndNavigationTests (the
// owner's MIT code) onto the seven fixed panes.
import Foundation
import OverbrightCore
import OverbrightDesign
import Testing
@testable import OverbrightSettingsUI

/// Rows like the ones WP11's panes list (synthetic: the panes are seeded empty).
private let rows: [SettingsRowInfo] = [
    SettingsRowInfo(.general, "launchBehavior", title: "When you log in", keywords: ["startup"]),
    SettingsRowInfo(.displays, "cap", title: "Limit", keywords: ["Safe", "Peak"]),
    SettingsRowInfo(.automations, "batteryGuard", title: "On battery"),
    SettingsRowInfo(.advanced, "resetDisplayColors", title: "Reset Display Colors…"),
]

private func index(rows: [SettingsRowInfo] = rows,
                   keywords: [SettingsPaneID: [String]] = KnownPaneKeywords.all) -> SettingsSearchIndex {
    SettingsSearchIndex(panes: SettingsPane.all, rows: rows, keywords: keywords)
}

@MainActor @Suite struct SearchAndNavigationTests {
    // MARK: Search

    /// The index follows what its rows were built from: rows that appear with a setting or an app state (From / To,
    /// Battery level, the icon warning) are found as soon as they show, not after the displays change (WP14).
    @Test func theIndexFollowsTheStateItsRowsDependOn() throws {
        let services = OverbrightServices.preview()
        let cache = SearchIndexCache()
        func finds(_ row: SettingsRowInfo) -> Bool {
            cache.index(panes: SettingsPane.all, signature: ["unchanged"]) { SettingsPaneCatalog.rows(services: services) }
                .search(row.title).rows.contains { $0.id == row.id }
        }
        #expect(!finds(AutomationsRows.scheduleFrom))
        services.settings[AutomationSettings.schedule] = ScheduleEditing.defaultWindow
        #expect(finds(AutomationsRows.scheduleFrom))
        #expect(finds(AutomationsRows.batteryThreshold))
        services.settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
        #expect(!finds(AutomationsRows.batteryThreshold))
        #expect(!finds(GeneralRows.iconWarning))
        let app = try #require(services.app as? PreviewAppControl)
        app.iconVisibility = .notVisible
        #expect(finds(GeneralRows.iconWarning))
    }

    /// A search hit on Run Self-Test… shows the row; only a deep link (the panel's Run Self-Test…) opens the sheet.
    @Test func onlyADeepLinkOpensTheSelfTestSheet() {
        let searched = SettingsNavigator(target: "general")
        searched.open(row: AdvancedRows.selfTest)
        #expect(searched.selection == .advanced && searched.highlightedRow == AdvancedPane.selfTestRowID)
        #expect(!searched.highlightIsDeepLink && !AdvancedPane.opensSelfTest(searched))
        let linked = SettingsNavigator(target: "general")
        linked.open("advanced#selfTest")
        #expect(linked.highlightIsDeepLink && AdvancedPane.opensSelfTest(linked))
        #expect(AdvancedPane.opensSelfTest(SettingsNavigator(target: "advanced#selfTest")))
        #expect(!AdvancedPane.opensSelfTest(SettingsNavigator(target: "advanced#detailedLogging")))
        #expect(!AdvancedPane.opensSelfTest(nil))
    }

    /// DESIGN.md §7.2's keyword list finds the pane that holds each subject.
    @Test func designKeywordsFindTheirPanes() {
        let search = index(rows: [])
        let expected: [(String, SettingsPaneID)] = [
            ("HDR", .displays), ("XDR", .displays), ("nits", .displays), ("brighter", .displays), ("dim", .displays),
            ("OLED", .displays), ("battery", .automations), ("shortcut", .shortcuts), ("camera", .fillLight),
            ("login", .general), ("quit", .general), ("flicker", .advanced), ("colors", .advanced),
        ]
        for (query, pane) in expected {
            #expect(search.search(query).panes.contains(pane), "\(query) → \(pane)")
        }
    }

    @Test func paneNamesAndRowLabelsAndRowKeywordsMatch() {
        let search = index()
        #expect(search.search("Fill").panes == [.fillLight])
        #expect(search.search("when you").rows.map(\.id) == ["general.launchBehavior"])
        #expect(search.search("peak").rows.map(\.id) == ["displays.cap"])
        #expect(search.search("peak").panes == [.displays])                           // the pane of a matching row
        #expect(search.search("reset display").rows.map(\.pane) == [.advanced])
    }

    @Test func keywordsMatchInTheirOwnLanguage() {
        // A pane lists localized keywords; in Russian the Displays pane would declare «яркость».
        let results = index(rows: [], keywords: [.displays: ["яркость", "нит"]]).search("Яркост")
        #expect(results.panes == [.displays])
    }

    @Test func matchingFoldsCaseAndDiacriticsAndNeedsWordStarts() {
        let words = SettingsSearchIndex.words(in: ["Ёлка", "Reset All Settings…"])
        #expect(SettingsSearchIndex.matches(words, SettingsSearchIndex.words(in: ["елк"])))
        #expect(SettingsSearchIndex.matches(words, SettingsSearchIndex.words(in: ["SETT"])))
        #expect(!SettingsSearchIndex.matches(words, SettingsSearchIndex.words(in: ["ttings"])))
        #expect(!SettingsSearchIndex.matches(words, SettingsSearchIndex.words(in: ["reset", "nothing"])))
    }

    @Test func aBlankQueryListsEveryPaneAndNoRows() {
        let search = index()
        let results = search.search("   ")
        #expect(results.rows.isEmpty && results.panes == SettingsPaneID.allCases)
        #expect(search.search("zzzz").isEmpty)
    }

    /// Rows of panes that do not exist are dropped; results keep sidebar order.
    @Test func rowsFollowTheSidebarOrder() {
        let mixed = [SettingsRowInfo(.advanced, "a", title: "Same"), SettingsRowInfo(.general, "b", title: "Same"),
                     SettingsRowInfo(.automations, "c", title: "Same")]
        #expect(index(rows: mixed).search("same").rows.map(\.pane) == [.general, .automations, .advanced])
    }

    /// The sidebar order and icons of DESIGN.md §7.1.
    @Test func thePanesAreTheDesignsSeven() {
        #expect(SettingsPane.all.map(\.id) == SettingsPaneID.allCases)
        #expect(SettingsPane.all.map(\.symbol.rawValue) == ["gearshape.fill", "display", "bolt.fill", "keyboard",
                                                            "person.crop.rectangle", "wrench.and.screwdriver.fill",
                                                            "info.circle.fill"])
        #expect(SettingsPane.pane(.about).namespaces.isEmpty)                         // About has no footer
        #expect(SettingsPane.pane(.general).namespaces == [.general, .updates])
    }

    /// Every row the seeded panes list belongs to its pane and has a unique id (WP11 keeps this true).
    @Test func catalogRowsAreUniqueAndInTheirPane() {
        let services = OverbrightServices.preview()
        let all = SettingsPaneCatalog.rows(services: services)
        #expect(Set(all.map(\.id)).count == all.count)
        for row in all { #expect(row.id.hasPrefix(row.pane.rawValue + ".")) }
        #expect(all.contains { $0.id == "about.acknowledgments" })
    }

    // MARK: Navigation and deep links

    @Test func deepLinksNameAPaneAndARow() {
        #expect(SettingsNavigator.parse("displays#cap") == (.displays, "displays.cap"))
        #expect(SettingsNavigator.parse("about") == (.about, nil))
        #expect(SettingsNavigator.parse("about#") == (.about, nil))
        #expect(SettingsNavigator.parse("FillLight") == (.fillLight, nil))              // case-insensitive pane names
        #expect(SettingsNavigator.parse("filllight#width") == (.fillLight, "fillLight.width"))
        #expect(SettingsNavigator.parse("nonsense#row") == (nil, nil))
        #expect(SettingsNavigator.parse(nil) == (nil, nil))
        #expect(SettingsRowInfo(.displays, "cap", title: "Limit").deepLink == "displays#cap")
    }

    @Test func navigatorScrollsOnlyTheRowsPane() {
        let navigator = SettingsNavigator(target: "about")
        #expect(navigator.selection == .about)
        navigator.open(row: rows[1])
        #expect(navigator.selection == .displays)
        #expect(navigator.highlightedRow == "displays.cap" && navigator.isHighlightFresh)
        #expect(navigator.takePendingRow(in: .about) == nil)                         // the old pane must not take it
        #expect(navigator.takePendingRow(in: .displays) == "displays.cap")
        #expect(navigator.takePendingRow(in: .displays) == nil)                      // once
        let serial = navigator.highlightSerial
        navigator.open("shortcuts")
        #expect(navigator.selection == .shortcuts && navigator.highlightSerial == serial)
        navigator.open("nonsense")                                                   // unknown: stays
        #expect(navigator.selection == .shortcuts)
    }

    @Test func anInitialDeepLinkOpensThePaneAtTheRowAndUnknownOpensGeneral() {
        let navigator = SettingsNavigator(target: "general#launchBehavior")
        #expect(navigator.selection == .general)
        #expect(navigator.takePendingRow(in: .general) == "general.launchBehavior")
        #expect(SettingsNavigator(target: "displays-old").selection == .general)
    }

    /// A session keeps the pane across opens; the window controller navigates it.
    @Test func sessionsNavigate() {
        let session = SettingsSession(services: .preview(), initialPane: "advanced")
        #expect(session.currentPane == .advanced)
        session.open("about")
        #expect(session.currentPane == .about)
        session.open(nil)
        #expect(session.currentPane == .about)
    }
}
