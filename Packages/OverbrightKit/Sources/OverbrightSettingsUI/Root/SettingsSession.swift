// OverbrightSettingsUI/Root/SettingsSession.swift — the Settings window's state, owned by the window controller so it
// outlives the views and the window itself: the pane shown (and a row to reveal), the search text and the sidebar's
// pick, and the Reset All offer. Opening a pane on a window that is already open navigates this state; nothing is
// rebuilt, so the Undo offer and the search survive a deep link from a chip, a banner, the menu or Help (DESIGN.md
// §7.1, §7.2). Closing Settings releases the window, its views and this session (`windowDidClose()` ends the Undo
// offer, DESIGN.md §7.8); the next open builds a new one at the pane shown last, with the search text of before
// (energy E3: nothing of Settings stays while it is closed, DESIGN.md §17). Ported from Cranny's SettingsSession (the
// owner's MIT code) without the preview stage.
import Foundation
import Observation
import OverbrightCore

/// The state behind the Settings window, for as long as it is open: pass it to the `SettingsRootView(session:)` built
/// for the window.
@Observable public final class SettingsSession {
    let services: OverbrightServices
    let navigator: SettingsNavigator
    let resetAll: ResetAllController
    /// The search index, built on the first query and again only when the panes or rows change.
    let searchIndex = SearchIndexCache()
    /// The sidebar's search text (Debug QA may start it with one, `SettingsQAOptions`); the window controller carries
    /// it from a closed window's session to the next.
    public var query = SettingsQAOptions.search ?? ""
    /// The sidebar row picked: a pane, or a setting the search found.
    var sidebarSelection: SidebarItem?

    /// Opens on `initialPane` ("pane" or "pane#row"; General when nil or unknown).
    public init(services: OverbrightServices, initialPane: String? = nil) {
        self.services = services
        let navigator = SettingsNavigator(target: initialPane)
        self.navigator = navigator
        resetAll = ResetAllController(services: services)
        sidebarSelection = .pane(navigator.selection)
    }

    /// Shows `pane` ("pane" or "pane#row", which also scrolls to the row and highlights it); nil keeps the pane.
    public func open(_ pane: String?) { navigator.open(pane) }

    /// The pane on screen.
    public var currentPane: SettingsPaneID { navigator.selection }

    /// Whether Reset All can still be undone (Undo Reset, ⌘Z) — until the window closes.
    public var canUndoReset: Bool { resetAll.canUndo }

    /// The window closed and its views are gone: the Undo offer of Reset All ends (DESIGN.md §7.8).
    public func windowDidClose() {
        resetAll.windowDidClose()
    }
}
