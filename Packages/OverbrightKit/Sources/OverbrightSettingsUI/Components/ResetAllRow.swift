// OverbrightSettingsUI/Components/ResetAllRow.swift — Advanced ▸ Reset All Settings… (DESIGN.md §7.8, §12.4): a
// destructive button that confirms first; afterwards Undo Reset stays beside it until the Settings window closes (⌘Z
// works too, and the banner shows for 10 s). WP11's Advanced pane places it; the offer lives in the session's
// `ResetAllController`.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Reset All with its confirmation and the Undo Reset button.
struct ResetAllRow: View {
    let controller: ResetAllController
    @State private var confirming = false

    /// The row (search: "reset").
    static var info: SettingsRowInfo {
        SettingsRowInfo(.advanced, "resetAll",
                        title: String(localized: "Reset All Settings…", bundle: .module,
                                      comment: "Settings ▸ Advanced: destructive button that resets every setting (title case)"))
    }

    var body: some View {
        HStack(spacing: Space.m) {
            Button(role: .destructive) { confirming = true } label: { Text(verbatim: Self.info.title) }
            if controller.canUndo {
                Button { controller.undo() } label: {
                    Text("Undo Reset", bundle: .module,
                         comment: "Settings ▸ Advanced: restores the settings from before Reset All, until Settings closes (title case)")
                }
            }
            Spacer(minLength: 0)
        }
        .searchTarget(Self.info)
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
    Form { ResetAllRow(controller: ResetAllController(services: .preview())) }
        .formStyle(.grouped)
        .frame(width: 600, height: 100)
}
