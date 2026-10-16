// OverbrightSettingsUI/Search/SettingsSearchIndex.swift — search over pane names, row labels and localized keywords
// (DESIGN.md §7.2: "HDR", "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "OLED",
// "flicker", "colors", "quit"). Ported from Cranny's SettingsSearchIndex (the owner's MIT code).
//
// Matching is case-, diacritic- and width-insensitive ("е" finds "ё"), and every word of the query must start a word of
// the entry ("ext disp" finds "external display"; "on" does not find "Reset").
import Foundation

/// The search index of the Settings sidebar.
struct SettingsSearchIndex {
    /// What a query found, in sidebar order.
    struct Results: Equatable {
        /// Panes whose name or keywords match, or that contain a matching row.
        var panes: [SettingsPaneID]
        /// Matching rows.
        var rows: [SettingsRowInfo]
        /// Nothing matched.
        var isEmpty: Bool { panes.isEmpty && rows.isEmpty }
    }

    private struct PaneEntry {
        let id: SettingsPaneID
        let words: [String]
    }

    private struct RowEntry {
        let info: SettingsRowInfo
        let words: [String]
    }

    private let panes: [PaneEntry]
    private let rows: [RowEntry]

    /// `panes` in sidebar order; `rows` of every pane; `keywords` add terms to the panes they name.
    init(panes: [SettingsPane], rows: [SettingsRowInfo], keywords: [SettingsPaneID: [String]] = [:]) {
        self.panes = panes.map { pane in
            PaneEntry(id: pane.id, words: Self.words(in: [pane.title] + (keywords[pane.id] ?? [])))
        }
        let order = Dictionary(panes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.rows = rows
            .filter { order[$0.pane] != nil }
            .enumerated()
            .sorted { (order[$0.element.pane] ?? 0, $0.offset) < (order[$1.element.pane] ?? 0, $1.offset) }
            .map { RowEntry(info: $0.element, words: Self.words(in: [$0.element.title] + $0.element.keywords)) }
    }

    /// The panes and rows `query` finds; every pane and no rows for a blank query.
    func search(_ query: String) -> Results {
        let tokens = Self.words(in: [query])
        guard !tokens.isEmpty else { return Results(panes: panes.map(\.id), rows: []) }
        let rowHits = rows.filter { Self.matches($0.words, tokens) }.map(\.info)
        let panesWithRows = Set(rowHits.map(\.pane))
        let paneHits = panes.filter { Self.matches($0.words, tokens) || panesWithRows.contains($0.id) }.map(\.id)
        return Results(panes: paneHits, rows: rowHits)
    }

    // MARK: Matching (pure)

    /// Every query token is a prefix of some word.
    static func matches(_ words: [String], _ tokens: [String]) -> Bool {
        tokens.allSatisfy { token in words.contains { $0.hasPrefix(token) } }
    }

    /// Folded words of `texts`: lowercased, without diacritics or width variants, split at non-alphanumerics.
    static func words(in texts: [String]) -> [String] {
        texts.flatMap { text in
            text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
        }
    }
}
