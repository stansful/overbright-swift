// OverbrightSettingsUI/Root/PaneContainer.swift — the detail column: the pane and its "Reset ‹Pane›…" footer (DESIGN.md
// §7.2). Ported from Cranny's SettingsRootView.swift (the owner's MIT code) without the preview stage.
import OverbrightCore
import SwiftUI

/// One pane with its footer.
struct PaneContainer: View {
    let pane: SettingsPane
    let services: OverbrightServices

    var body: some View {
        SettingsPaneCatalog.view(for: pane.id, services: services)
            .id(pane.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !pane.namespaces.isEmpty {
                    PaneFooter(pane: pane, settings: services.settings)
                }
            }
    }
}

#Preview("Pane with its footer") {
    PaneContainer(pane: .pane(.general), services: .preview())
        .environment(SettingsNavigator(target: "general"))
        .frame(width: 650, height: 400)
}

#Preview("About (no footer)") {
    PaneContainer(pane: .pane(.about), services: .preview())
        .environment(SettingsNavigator(target: "about"))
        .frame(width: 650, height: 400)
}
