// OverbrightSettingsUI/Panes/AutomationsPane.swift — Settings ▸ Automations (DESIGN.md §7.5): battery, Low Power, heat
// note, timer, apps and video, schedule, OLED idle, Focus.
// Seeded empty by WP0b (ARCHITECTURE.md §10.2) behind the `SettingsPaneView` seam; WP11 owns this file and fills every
// row of DESIGN.md §7.5 with its defaults, ranges, footnotes, search keywords and deep links (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ Automations.
struct AutomationsPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (WP11 lists every row it draws).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { [] }

    var body: some View {
        SettingsForm(.automations) {
        }
    }
}

#Preview("Automations") {
    AutomationsPane(services: .preview())
        .frame(width: 650, height: 500)
}
