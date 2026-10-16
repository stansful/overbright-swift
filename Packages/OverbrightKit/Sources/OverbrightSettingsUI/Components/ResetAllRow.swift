// OverbrightSettingsUI/Components/ResetAllRow.swift — Advanced ▸ Reset All Settings… (DESIGN.md §7.8, §12.4): a
// destructive button that confirms first; afterwards Undo Reset stays beside it until the Settings window closes (⌘Z
// works too, and the banner shows for 10 s). WP11's Advanced pane places it and passes the button's title: DESIGN's
// "Reset All Settings…" trips Core's `noSettingsDestinationLabels` lint (it reads as "‹X› Settings…", a settings
// place), so that key waits for the lint's refinement through the contract lane. The offer lives in the session's
// `ResetAllController`.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Reset All with its confirmation and the Undo Reset button.
struct ResetAllRow: View {
    let controller: ResetAllController
    /// The button's title, localized by the pane (DESIGN.md §7.8).
    let title: String
    @State private var confirming = false

    /// The row with `title` (search: "reset" finds the pane through `KnownPaneKeywords`).
    static func info(title: String) -> SettingsRowInfo {
        SettingsRowInfo(.advanced, "resetAll", title: title)
    }

    var body: some View {
        HStack(spacing: Space.m) {
            Button(role: .destructive) { confirming = true } label: { Text(verbatim: title) }
            if controller.canUndo {
                Button { controller.undo() } label: {
                    Text("Undo Reset", bundle: .module,
                         comment: "Settings ▸ Advanced: restores the settings from before Reset All, until Settings closes (title case)")
                }
            }
            Spacer(minLength: 0)
        }
        .searchTarget(Self.info(title: title))
        .alert(Text("Reset all settings?", bundle: .module, comment: "Settings ▸ Advanced: confirmation title of Reset All"),
               isPresented: $confirming) {
            Button(role: .destructive) { controller.resetAll() } label: {
                Text("Reset All", bundle: .module, comment: "Settings ▸ Advanced: confirms Reset All (title case)")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel", bundle: .module, comment: "Settings: cancel button of a confirmation (title case)")
            }
        } message: {
            Text("Every Overbright setting returns to its default, including display calibration.", bundle: .module,
                 comment: "Settings ▸ Advanced: confirmation message of Reset All")
        }
    }
}

#Preview("Reset All") {
    Form { ResetAllRow(controller: ResetAllController(services: .preview()), title: "Reset All…") }
        .formStyle(.grouped)
        .frame(width: 600, height: 100)
}
