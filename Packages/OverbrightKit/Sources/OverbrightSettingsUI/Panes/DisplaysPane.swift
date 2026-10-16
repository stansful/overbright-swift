// OverbrightSettingsUI/Panes/DisplaysPane.swift — Settings ▸ Displays (DESIGN.md §7.4): all displays; one section per
// display: verdict, extra brightness, level, limit, method, calibration, type.
// Seeded empty by WP0b (ARCHITECTURE.md §10.2) behind the `SettingsPaneView` seam; WP11 owns this file and fills every
// row of DESIGN.md §7.4 with its defaults, ranges, footnotes, search keywords and deep links (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ Displays.
struct DisplaysPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (WP11 lists every row it draws).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { [] }

    var body: some View {
        SettingsForm(.displays) {
        }
    }
}

#Preview("Displays") {
    DisplaysPane(services: .preview())
        .frame(width: 650, height: 500)
}
