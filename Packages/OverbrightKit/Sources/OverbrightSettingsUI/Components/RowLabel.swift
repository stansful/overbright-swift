// OverbrightSettingsUI/Components/RowLabel.swift — a row's label and its one-line footnote in `.secondary` (DESIGN.md
// §7.2). The changed-value dot and Reset to Default come from Design's `overbrightSettingRow` (`settingRow`). Ported
// from Cranny's SettingRow.swift (the owner's MIT code).
import OverbrightDesign
import SwiftUI

/// A row's title and optional footnote.
struct RowLabel: View {
    let title: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(verbatim: title)
            if let footnote {
                Text(verbatim: footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Row label") {
    Form {
        Toggle(isOn: .constant(true)) {
            RowLabel(title: "Show level changes on screen",
                     footnote: "When you use a shortcut, the Shortcuts app or a Focus.")
        }
    }
    .formStyle(.grouped)
    .toggleStyle(.switch)
    .controlSize(.small)
    .frame(width: 520, height: 140)
}
