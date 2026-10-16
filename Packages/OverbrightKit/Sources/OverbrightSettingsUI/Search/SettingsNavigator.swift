// OverbrightSettingsUI/Search/SettingsNavigator.swift — which pane is shown and which row a search result or a deep
// link asked for (DESIGN.md §7.2: "a result opens the pane, scrolls to the row and highlights it with an accent wash
// fading over 1 s"). Ported from Cranny's SettingsNavigator (the owner's MIT code). A deep link is "pane" or
// "pane#row": `displays#cap` opens Displays, scrolls to the Limit row and washes it with the accent.
// `AppControl.openSettings(_:)`, `overbright://settings/<pane>` and the Debug `--qa-settings` hook pass it unchanged.
import Foundation
import Observation

/// The shown pane and the row to reveal.
@Observable final class SettingsNavigator {
    /// The pane in the detail column.
    var selection: SettingsPaneID
    /// The row to scroll to; `SettingsForm` consumes it once the pane's rows exist.
    private(set) var pendingRow: String?
    /// The row to wash with the accent, bumped on every request so a repeat flashes again.
    private(set) var highlightedRow: String?
    /// Bumped on every reveal (a repeat of the same row flashes again).
    private(set) var highlightSerial = 0
    @ObservationIgnored private(set) var highlightDate = Date.distantPast

    /// Opens `target` ("pane" or "pane#row"; General when nil or unknown).
    init(target: String? = nil) {
        let parsed = Self.parse(target)
        selection = parsed.pane ?? .general
        if let row = parsed.row { reveal(row) }
    }

    /// Opens a pane or a deep link ("displays#cap"); nil or an unknown pane keeps the current pane.
    func open(_ target: String?) {
        let parsed = Self.parse(target)
        if let pane = parsed.pane, pane != selection { selection = pane }
        if let row = parsed.row { reveal(row) }
    }

    /// Opens `row`'s pane, scrolls to it and highlights it.
    func open(row: SettingsRowInfo) {
        if selection != row.pane { selection = row.pane }
        reveal(row.id)
    }

    /// Called by `pane`'s form: the row to scroll to if it belongs to that pane (at most once per request).
    func takePendingRow(in pane: SettingsPaneID) -> String? {
        guard let row = pendingRow, row.hasPrefix(pane.rawValue + ".") else { return nil }
        pendingRow = nil
        return row
    }

    /// A highlight is shown only shortly after it was requested, so rows that scroll in later stay calm.
    var isHighlightFresh: Bool { Date().timeIntervalSince(highlightDate) < 2 }

    private func reveal(_ row: String) {
        pendingRow = row
        highlightedRow = row
        highlightDate = Date()
        highlightSerial += 1
    }

    // MARK: Deep links (pure, tested)

    /// "displays#cap" → (displays, "displays.cap"); "about" → (about, nil); an unknown pane or nil → (nil, nil).
    static func parse(_ target: String?) -> (pane: SettingsPaneID?, row: String?) {
        guard let raw = target?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return (nil, nil) }
        let parts = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let pane = SettingsPaneID(link: String(parts[0])) else { return (nil, nil) }
        guard parts.count == 2, !parts[1].isEmpty else { return (pane, nil) }
        return (pane, "\(pane.rawValue).\(parts[1])")
    }
}
