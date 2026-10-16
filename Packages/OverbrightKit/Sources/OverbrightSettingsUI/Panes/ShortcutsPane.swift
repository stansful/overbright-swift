// OverbrightSettingsUI/Panes/ShortcutsPane.swift — Settings ▸ Shortcuts (DESIGN.md §7.6): recorders (`ShortcutRow`),
// step size, Shortcuts app and Control Center.
// Seeded empty by WP0b (ARCHITECTURE.md §10.2) behind the `SettingsPaneView` seam; WP11 owns this file and fills every
// row of DESIGN.md §7.6 with its defaults, ranges, footnotes, search keywords and deep links (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ Shortcuts.
struct ShortcutsPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (WP11 lists every row it draws).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { [] }

    var body: some View {
        SettingsForm(.shortcuts) {
        }
    }
}

#Preview("Shortcuts") {
    ShortcutsPane(services: .preview())
        .frame(width: 650, height: 500)
}
