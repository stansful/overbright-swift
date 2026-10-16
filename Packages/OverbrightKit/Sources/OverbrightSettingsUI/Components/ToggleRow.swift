// OverbrightSettingsUI/Components/ToggleRow.swift — a switch row backed by a Bool key: `.switch` and `.small` (DESIGN.md
// §7.2). Ported from Cranny's SettingControls.swift (the owner's MIT code).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// A switch row.
struct ToggleRow: View {
    let info: SettingsRowInfo
    let settings: SettingsStore
    let key: SettingKey<Bool>
    var footnote: String?

    var body: some View {
        Toggle(isOn: settings.binding(key)) {
            RowLabel(title: info.title, footnote: footnote)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .settingRow(info, settings: settings, key: key)
    }
}

#Preview("Toggle row") {
    let services = OverbrightServices.preview()
    Form {
        ToggleRow(info: SettingsRowInfo(.general, "showsHUD", title: "Show level changes on screen"),
                  settings: services.settings, key: GeneralSettings.showsHUD,
                  footnote: "When you use a shortcut, the Shortcuts app or a Focus.")
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 120)
}
