// OverbrightSettingsUI/Panes/MenuBarIconRow.swift — General ▸ Show menu bar icon (DESIGN.md §4.4, §7.3): turning it off
// asks first, and the question says how to reach Overbright without the icon: Finder or Spotlight (which shows
// Settings), the on/off shortcut in the live key caps when one is registered, and Quit Overbright in Settings.
// Turning it on shows the icon at once. Both go through `AppControl.setMenuBarIconVisible`.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Show menu bar icon, with the question before hiding it.
struct MenuBarIconRow: View {
    let services: OverbrightServices
    @State private var confirmingHide = false

    var body: some View {
        let isOn = Binding<Bool>(get: { services.settings[GeneralSettings.showsMenuBarIcon] }, set: { visible in
            if visible { GeneralPane.setMenuBarIconVisible(true, services: services) } else { confirmingHide = true }
        })
        Toggle(isOn: isOn) {
            RowLabel(title: GeneralRows.menuBarIcon.title,
                     footnote: String(localized: "When it’s hidden, open Overbright from Finder or Spotlight to see Settings.",
                                      bundle: .module, comment: "Settings ▸ General: footnote of Show menu bar icon"))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .alert(Text("Hide the menu bar icon?", bundle: .module, comment: "Settings ▸ General: title of the question before hiding the menu bar icon"),
               isPresented: $confirmingHide) {
            Button { GeneralPane.setMenuBarIconVisible(false, services: services) } label: {
                Text("Hide Icon", bundle: .module, comment: "Settings ▸ General: confirms hiding the menu bar icon (title case)")
            }
            Button(role: .cancel) {} label: { Text(verbatim: PaneWords.cancel) }
        } message: {
            Text(verbatim: Self.hideMessage(toggleKeys: services.shortcuts.displayString(.toggle)))
        }
    }

    /// The question's text: the shortcut clause only while the on/off shortcut is registered (DESIGN.md §4.4).
    static func hideMessage(toggleKeys: String?) -> String {
        guard let toggleKeys else {
            return String(localized: "You can still open Overbright from Finder or Spotlight, which shows Settings. To quit, open Overbright again and click Quit Overbright in Settings.",
                          bundle: .module, comment: "Settings ▸ General: text of the question before hiding the menu bar icon, without an on/off shortcut")
        }
        return String(localized: "You can still open Overbright from Finder or Spotlight, which shows Settings, or use \(toggleKeys) to turn it on or off. To quit, open Overbright again and click Quit Overbright in Settings.",
                      bundle: .module,
                      comment: "Settings ▸ General: text of the question before hiding the menu bar icon; the placeholder is the live key caps of the on/off shortcut")
    }
}

#Preview("Show menu bar icon") {
    Form { MenuBarIconRow(services: .preview()) }
        .formStyle(.grouped)
        .frame(width: 600, height: 120)
}
