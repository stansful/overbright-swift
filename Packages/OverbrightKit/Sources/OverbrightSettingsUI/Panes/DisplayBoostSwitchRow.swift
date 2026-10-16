// OverbrightSettingsUI/Panes/DisplayBoostSwitchRow.swift — Displays ▸ ‹display› ▸ Use extra brightness on this display
// (DESIGN.md §7.4, D8): the per-display switch of the boost half, on by default for built-in XDR and Apple XDR
// displays and off for other HDR and OLED displays; dimming works either way. Turning it on for an OLED display asks
// first (§12.4), once: the answer is remembered with the display's preferences.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The per-display switch of extra brightness.
struct DisplayBoostSwitchRow: View {
    let services: OverbrightServices
    let model: DisplaySectionModel
    let value: RowValue
    @State private var asksOLED = false

    private var editor: DisplayPreferencesEditor { DisplayPreferencesEditor(settings: services.settings) }

    var body: some View {
        let isOn = Binding<Bool>(get: { model.boostEnabled }, set: { on in
            if on, model.isOLED, !model.preferences.oledNoticeAcknowledged {
                asksOLED = true
            } else {
                editor.update(model.key, name: model.name) { $0.boostEnabled = on }
            }
        })
        Toggle(isOn: isOn) {
            RowLabel(title: value.info.title,
                     footnote: String(localized: "Dimming below the minimum works either way.", bundle: .module,
                                      comment: "Settings ▸ Displays: footnote of Use extra brightness on this display"))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .settingRow(value)
        .oledNotice(isPresented: $asksOLED, idleMinutes: services.settings[AutomationSettings.oledIdleMinutes]) {
            editor.update(model.key, name: model.name) { $0.boostEnabled = true; $0.oledNoticeAcknowledged = true }
        }
    }
}
