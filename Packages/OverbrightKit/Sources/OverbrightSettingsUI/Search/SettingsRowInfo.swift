// OverbrightSettingsUI/Search/SettingsRowInfo.swift — one searchable row of a pane. DESIGN.md §7.2 (search, deep
// links). Ported from Cranny's SettingsRowInfo (the owner's MIT code). The pane draws its label from `title` and the
// search index reads the same value, so what you can find is exactly what you see. `id` is stable
// ("displays.cap") and doubles as the deep-link target ("displays#cap", see `SettingsNavigator`).
import Foundation

/// A row a search result can point at: its pane, its localized label and extra localized search terms.
struct SettingsRowInfo: Identifiable, Hashable {
    /// "<pane>.<name>", e.g. "general.launchBehavior". Stable: deep links and scroll targets use it.
    let id: String
    /// The pane that shows the row.
    let pane: SettingsPaneID
    /// Localized label, exactly as the row shows it.
    let title: String
    /// Localized synonyms ("HDR", "nits", "brighter"). Never shown.
    let keywords: [String]

    /// The row `name` of `pane`.
    init(_ pane: SettingsPaneID, _ name: String, title: String, keywords: [String] = []) {
        self.id = "\(pane.rawValue).\(name)"
        self.pane = pane
        self.title = title
        self.keywords = keywords
    }

    /// The deep link that opens this row ("general#launchBehavior"; `SettingsNavigator.parse` reads it back).
    var deepLink: String { "\(pane.rawValue)#\(id.dropFirst(pane.rawValue.count + 1))" }
}
