// OverbrightSettingsUI/Panes/AboutPane.swift — Settings ▸ About (DESIGN.md §7.9): version, updates, license,
// acknowledgments, privacy, Show Welcome. Seeded by WP0b (ARCHITECTURE.md §10.2) with WP0b's `AboutContent`; WP11 owns
// this file (§10.13).
import OverbrightCore
import SwiftUI

/// Settings ▸ About.
struct AboutPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] { AboutContent.rows(services: services) }

    var body: some View {
        SettingsForm(.about) {
            AboutContent(services: services)
        }
    }
}

#Preview("About") {
    AboutPane(services: .preview())
        .frame(width: 650, height: 620)
}
