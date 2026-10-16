// OverbrightSettingsUI/Panes/FillLightPane.swift — Settings ▸ Fill Light (DESIGN.md §7.7): preview, switch, display,
// width, warmth, brightness, camera rule.
// Seeded empty by WP0b (ARCHITECTURE.md §10.2) behind the `SettingsPaneView` seam; WP11 owns this file and fills every
// row of DESIGN.md §7.7 with its defaults, ranges, footnotes, search keywords and deep links (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ Fill Light.
struct FillLightPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (WP11 lists every row it draws).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { [] }

    var body: some View {
        SettingsForm(.fillLight) {
        }
    }
}

#Preview("Fill Light") {
    FillLightPane(services: .preview())
        .frame(width: 650, height: 500)
}
