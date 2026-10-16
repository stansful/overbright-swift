// OverbrightSettingsUI/Root/SettingsSidebar.swift — the sidebar (DESIGN.md §7.1): one row per pane, each a 20 × 20
// rounded-square icon (radius 5, continuous) with a white glyph on a system colour, as in System Settings. While
// searching it lists the matching panes and, below them, the matching settings with their pane; picking one opens the
// pane at that row. Ported from Cranny's SettingsSidebar (the owner's MIT code).
import Foundation
import OverbrightDesign
import SwiftUI

/// What a sidebar row points at.
enum SidebarItem: Hashable {
    case pane(SettingsPaneID)
    case row(SettingsRowInfo)
}

/// The searchable sidebar.
struct SettingsSidebar: View {
    /// Every pane in sidebar order.
    let panes: [SettingsPane]
    /// nil while the search field is empty.
    let results: SettingsSearchIndex.Results?
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            if let results {
                searchResults(results)
            } else {
                ForEach(panes) { pane in
                    PaneLabel(pane: pane).tag(SidebarItem.pane(pane.id))
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder private func searchResults(_ results: SettingsSearchIndex.Results) -> some View {
        if results.isEmpty {
            Text("No Results", bundle: .module, comment: "Settings: the sidebar search found nothing (title case, as macOS writes it)")
                .foregroundStyle(.secondary)
                .selectionDisabled()
        } else {
            Section {
                ForEach(results.panes, id: \.self) { id in
                    if let pane = panes.first(where: { $0.id == id }) {
                        PaneLabel(pane: pane).tag(SidebarItem.pane(pane.id))
                    }
                }
            }
            if !results.rows.isEmpty {
                Section {
                    ForEach(results.rows) { row in
                        if let pane = panes.first(where: { $0.id == row.pane }) {
                            RowResultLabel(row: row, pane: pane).tag(SidebarItem.row(row))
                        }
                    }
                } header: {
                    Text("Settings", bundle: .module, comment: "Settings: sidebar header above the settings (rows) a search found")
                }
            }
        }
    }
}

/// A pane row: icon and name.
struct PaneLabel: View {
    let pane: SettingsPane
    var body: some View {
        Label {
            Text(verbatim: pane.title)
        } icon: {
            SidebarIcon(symbol: pane.symbol, tint: pane.tint)
        }
    }
}

/// A search hit on a row: the row's label with its pane's icon and name below.
struct RowResultLabel: View {
    let row: SettingsRowInfo
    let pane: SettingsPane
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SettingsMetrics.searchHitLineGap) {
                Text(verbatim: row.title).lineLimit(1)
                Text(verbatim: pane.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } icon: {
            SidebarIcon(symbol: pane.symbol, tint: pane.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 20 × 20 rounded square (radius 5, continuous), white glyph on a system colour, as in System Settings.
struct SidebarIcon: View {
    let symbol: OverbrightSymbol
    let tint: SettingsPane.Tint
    var body: some View {
        Image(symbol: symbol)
            .font(.system(size: SettingsMetrics.sidebarGlyph, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: SettingsMetrics.sidebarIcon, height: SettingsMetrics.sidebarIcon)
            .background(RoundedRectangle(cornerRadius: SettingsMetrics.sidebarIconRadius, style: .continuous)
                .fill(tint.color.gradient))
            .accessibilityHidden(true)
    }
}

#Preview("Sidebar") {
    @Previewable @State var selection: SidebarItem? = .pane(.general)
    SettingsSidebar(panes: SettingsPane.all, results: nil, selection: $selection)
        .frame(width: 210, height: 420)
}

#Preview("Sidebar · search") {
    @Previewable @State var selection: SidebarItem?
    let index = SettingsSearchIndex(panes: SettingsPane.all, rows: [], keywords: KnownPaneKeywords.all)
    SettingsSidebar(panes: SettingsPane.all, results: index.search("battery"), selection: $selection)
        .frame(width: 210, height: 420)
}
