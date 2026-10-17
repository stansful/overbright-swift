// OverbrightSettingsUI/Root/SettingsRootView.swift — the Settings window content (DESIGN.md §7.1, D15): a
// `NavigationSplitView` with the searchable sidebar of the seven panes, the pane itself and its "Reset ‹Pane›…"
// footer, the "All settings were reset." banner (10 s) and ⌘Z for Undo Reset until the window closes (through the
// window's undo manager, which the view hands to `ResetAllController`, so a focused text field keeps its own undo).
// Its state lives in a `SettingsSession`, which the window controller keeps and navigates, also while no window
// exists. Ported from Cranny's SettingsRootView (the owner's MIT code) without the preview stage and the module panes.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Settings window's content.
public struct SettingsRootView: View {
    private let onPaneChange: (@MainActor (SettingsPaneID) -> Void)?
    @State private var session: SettingsSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager

    /// Shows `session`, which the caller keeps to navigate the open window (`SettingsSession.open(_:)`).
    /// `onPaneChange` reports the pane shown, so the window can restore it next time and take its title.
    public init(session: SettingsSession, onPaneChange: (@MainActor (SettingsPaneID) -> Void)? = nil) {
        self.onPaneChange = onPaneChange
        _session = State(initialValue: session)
    }

    private var navigator: SettingsNavigator { session.navigator }
    private var resetAll: ResetAllController { session.resetAll }

    public var body: some View {
        let panes = SettingsPane.all
        let trimmed = session.query.trimmingCharacters(in: .whitespacesAndNewlines)
        NavigationSplitView {
            SettingsSidebar(panes: panes, results: trimmed.isEmpty ? nil : searchIndex(panes).search(trimmed),
                            selection: $session.sidebarSelection)
                .searchable(text: $session.query, placement: .sidebar,
                            prompt: Text("Search", bundle: .module, comment: "Settings: placeholder of the sidebar search field"))
                .navigationSplitViewColumnWidth(min: SettingsMetrics.sidebarWidth.min,
                                                ideal: SettingsMetrics.sidebarWidth.ideal,
                                                max: SettingsMetrics.sidebarWidth.max)
        } detail: {
            let pane = SettingsPane.pane(navigator.selection)
            PaneContainer(pane: pane, services: session.services)
                .navigationTitle(Text(verbatim: pane.title))
        }
        .overlay(alignment: .bottom) {
            if resetAll.showsBanner {
                UndoBanner(controller: resetAll)
                    .padding(.bottom, SettingsMetrics.bannerInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        // ⌘Z undoes Reset All until the window closes (DESIGN.md §7.8), banner or not: Edit ▸ Undo through the
        // responder chain, so the search field's own typing is undone first.
        .onAppear { resetAll.undoManager = undoManager }
        .onChange(of: undoManager.map(ObjectIdentifier.init)) { resetAll.undoManager = undoManager }
        .animation(OverbrightTheme(reduceMotion: reduceMotion).animation(.bannerIn), value: resetAll.showsBanner)
        .environment(navigator)
        .environment(resetAll)
        .frame(minWidth: SettingsMetrics.minimumWindowSize.width, minHeight: SettingsMetrics.minimumWindowSize.height)
        .onChange(of: session.sidebarSelection) { _, item in
            switch item {
            case .pane(let id)?: navigator.open(id.rawValue)
            case .row(let row)?: navigator.open(row: row)
            case nil: break
            }
        }
        .onChange(of: navigator.selection, initial: true) { _, selection in
            if !Self.item(session.sidebarSelection, points: selection) { session.sidebarSelection = .pane(selection) }
            onPaneChange?(selection)
        }
        .onChange(of: trimmed.isEmpty) { _, isEmpty in
            if isEmpty { session.sidebarSelection = .pane(navigator.selection) }
        }
        .overbrightThemeRoot()
    }

    /// The index for a query: rebuilt when the displays or the app names it lists change (the signature), and when a
    /// setting or app state the rows read changes (`SearchIndexCache` observes building the rows).
    private func searchIndex(_ panes: [SettingsPane]) -> SettingsSearchIndex {
        let services = session.services
        let signature = [String(services.displays.generation), String(AppIdentityResolver.shared.revision),
                         String(services.updates.isConfigured)]
        return session.searchIndex.index(panes: panes, signature: signature) {
            SettingsPaneCatalog.rows(services: services)
        }
    }

    /// The sidebar item already shows `pane` (its own row, or a search hit inside it).
    private static func item(_ item: SidebarItem?, points pane: SettingsPaneID) -> Bool {
        switch item {
        case .pane(let id)?: id == pane
        case .row(let row)?: row.pane == pane
        case nil: false
        }
    }
}

#Preview("Settings") {
    SettingsRootView(session: SettingsSession(services: .preview()))
        .frame(width: 860, height: 620)
}

#Preview("Settings · About") {
    SettingsRootView(session: SettingsSession(services: .preview(), initialPane: "about"))
        .frame(width: 860, height: 620)
}
