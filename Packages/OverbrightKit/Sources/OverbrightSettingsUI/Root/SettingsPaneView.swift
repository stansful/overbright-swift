// OverbrightSettingsUI/Root/SettingsPaneView.swift — the seam between the Settings infrastructure (WP0b) and the panes
// (WP11). ARCHITECTURE.md §10.2, §10.13. Every pane in Panes/ conforms; `SettingsPaneCatalog` builds them and indexes
// their rows. A pane draws its rows with the Components/ row kinds and `SettingsForm(pane)`, so search results and deep
// links ("displays#cap") scroll to and highlight them.
import OverbrightCore
import SwiftUI

/// A Settings pane.
protocol SettingsPaneView: View {
    /// The pane for `services`.
    init(services: OverbrightServices)
    /// Every searchable row the pane shows, with the same labels and keywords it draws (the search finds exactly what
    /// you see). Rows of things that come and go (one per display) are listed for what is there now.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo]
}
