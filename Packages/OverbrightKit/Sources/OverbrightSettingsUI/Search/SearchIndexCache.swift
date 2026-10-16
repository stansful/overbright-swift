// OverbrightSettingsUI/Search/SearchIndexCache.swift — builds the search index only while a query is typed and reuses
// it until what it indexes changes. Ported from Cranny's SettingsSession.swift (the owner's MIT code).
import Foundation

/// The search index for the current panes and rows.
final class SearchIndexCache {
    private var index: SettingsSearchIndex?
    private var signature: [String] = []

    /// The index of `panes` and `rows()`; `signature` names what they depend on (it is cheap to compute, the rows are
    /// not: building them reads every pane's labels).
    func index(panes: [SettingsPane], signature: [String], rows: () -> [SettingsRowInfo]) -> SettingsSearchIndex {
        if let index, signature == self.signature { return index }
        let built = SettingsSearchIndex(panes: panes, rows: rows(), keywords: KnownPaneKeywords.all)
        index = built
        self.signature = signature
        return built
    }
}
