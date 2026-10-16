// OverbrightSettingsUI/Components/PaneFooter.swift — every pane with settings ends with "Reset ‹Pane›…" (DESIGN.md
// §7.2, §12.9), pinned under the pane's scrolling content, which resets the pane's namespaces after a confirmation.
// Ported from Cranny's PaneFooter (the owner's MIT code).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The "Reset ‹Pane›…" footer.
struct PaneFooter: View {
    let pane: SettingsPane
    let settings: SettingsStore
    @State private var confirming = false

    var body: some View {
        HStack {
            Spacer()
            Button {
                confirming = true
            } label: {
                Text("Reset \(pane.title)…", bundle: .module,
                     comment: "Settings: pane footer button (title case); the argument is the pane name (\"Reset General…\")")
            }
            .disabled(pane.namespaces.isEmpty)
        }
        .padding(.horizontal, Space.xxl)
        .padding(.vertical, Space.m)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .alert(Text("Reset \(pane.title) settings?", bundle: .module,
                    comment: "Settings: confirmation title of a pane reset; the argument is the pane name"),
               isPresented: $confirming) {
            Button(role: .destructive) {
                PaneReset.reset(pane.namespaces, settings: settings)
            } label: {
                Text("Reset", bundle: .module, comment: "Settings: confirm button of a pane reset (title case)")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel", bundle: .module, comment: "Settings: cancel button of a confirmation (title case)")
            }
        } message: {
            Text(verbatim: Self.message(for: pane))
        }
    }

    /// "Every setting in ‹Pane› returns to its default." (Displays adds display calibration, DESIGN.md §12.9.)
    static func message(for pane: SettingsPane) -> String {
        if pane.id == .displays {
            return String(localized: "Every setting in \(pane.title) returns to its default, including display calibration.",
                          bundle: .module,
                          comment: "Settings ▸ Displays: confirmation message of the pane reset; the argument is the pane name")
        }
        return String(localized: "Every setting in \(pane.title) returns to its default.", bundle: .module,
                      comment: "Settings: confirmation message of a pane reset; the argument is the pane name")
    }
}

#Preview("Pane footer") {
    PaneFooter(pane: .pane(.general), settings: OverbrightServices.preview().settings)
        .frame(width: 600)
}
