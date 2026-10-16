// OverbrightSettingsUI/Root/SettingsPaneCatalog.swift — which view and which searchable rows each pane has.
// ARCHITECTURE.md §10.2 (the infrastructure), §10.13 (WP11 writes the panes behind `SettingsPaneView`).
import OverbrightCore
import SwiftUI

/// The views and rows of the seven panes.
enum SettingsPaneCatalog {
    /// The pane's view.
    @ViewBuilder static func view(for pane: SettingsPaneID, services: OverbrightServices) -> some View {
        switch pane {
        case .general: GeneralPane(services: services)
        case .displays: DisplaysPane(services: services)
        case .automations: AutomationsPane(services: services)
        case .shortcuts: ShortcutsPane(services: services)
        case .fillLight: FillLightPane(services: services)
        case .advanced: AdvancedPane(services: services)
        case .about: AboutPane(services: services)
        }
    }

    /// Every searchable row of every pane, in sidebar order.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        GeneralPane.rows(services: services) + DisplaysPane.rows(services: services)
            + AutomationsPane.rows(services: services) + ShortcutsPane.rows(services: services)
            + FillLightPane.rows(services: services) + AdvancedPane.rows(services: services)
            + AboutPane.rows(services: services)
    }
}
