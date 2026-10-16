// OverbrightSettingsUI/Panes/AdvancedPane.swift — Settings ▸ Advanced (DESIGN.md §7.8): diagnostics, self-test, other
// apps, trigger method, recovery, Reset All with Undo (`ResetAllRow`).
// Seeded empty by WP0b (ARCHITECTURE.md §10.2) behind the `SettingsPaneView` seam; WP11 owns this file and fills every
// row of DESIGN.md §7.8 with its defaults, ranges, footnotes, search keywords and deep links (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ Advanced.
struct AdvancedPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (WP11 lists every row it draws).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { [] }

    var body: some View {
        SettingsForm(.advanced) {
        }
    }
}

#Preview("Advanced") {
    AdvancedPane(services: .preview())
        .frame(width: 650, height: 500)
}
