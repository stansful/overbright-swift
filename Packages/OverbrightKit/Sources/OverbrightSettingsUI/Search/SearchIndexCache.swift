// OverbrightSettingsUI/Search/SearchIndexCache.swift — builds the search index only while a query is typed and reuses
// it until what it indexes changes. Ported from Cranny's SettingsSession.swift (the owner's MIT code). As built
// (WP14): besides the signature, building the rows is observed, so any setting, display or app state a pane's row list
// read (the schedule's From / To, Battery level, OLED idle, the icon warning) makes the next query rebuild the index.
import Foundation
import Observation
import os

/// The search index for the current panes and rows.
final class SearchIndexCache {
    private var index: SettingsSearchIndex?
    private var signature: [String] = []
    /// Set (from any thread, by Observation) when something the rows were built from changed.
    private let stale = OSAllocatedUnfairLock(initialState: true)

    /// The index of `panes` and `rows()`; `signature` names what they depend on beyond what `rows()` reads through
    /// Observation (it is cheap to compute, the rows are not: building them reads every pane's labels).
    func index(panes: [SettingsPane], signature: [String], rows: () -> [SettingsRowInfo]) -> SettingsSearchIndex {
        if let index, signature == self.signature, !stale.withLock({ $0 }) { return index }
        stale.withLock { $0 = false }
        let flag = stale
        let built = withObservationTracking {
            SettingsSearchIndex(panes: panes, rows: rows(), keywords: KnownPaneKeywords.all)
        } onChange: { @Sendable in
            flag.withLock { $0 = true }
        }
        index = built
        self.signature = signature
        return built
    }
}
