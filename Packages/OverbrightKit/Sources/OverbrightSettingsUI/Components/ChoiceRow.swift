// OverbrightSettingsUI/Components/ChoiceRow.swift — a picker row: segmented for up to four short options, a pop-up
// otherwise (DESIGN.md §7.2); segments fall back to a pop-up when a translation does not fit. Ported from Cranny's
// SettingControls.swift (the owner's MIT code).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// One option of a picker row.
struct Choice<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var id: Value { value }
}

/// How a picker row draws its options.
enum ChoiceStyle {
    /// Segmented for up to four options, a pop-up otherwise.
    case automatic
    /// Always segmented (falls back to a pop-up when it does not fit).
    case segmented
    /// Always a pop-up.
    case menu
}

/// A picker row. `init(_:settings:key:…)` binds a settings key; the memberwise form takes any binding.
struct ChoiceRow<Value: Hashable>: View {
    let info: SettingsRowInfo
    let selection: Binding<Value>
    let choices: [Choice<Value>]
    var footnote: String?
    var style: ChoiceStyle = .automatic
    let isDefault: Bool
    let reset: @MainActor () -> Void

    var body: some View {
        let picker = Picker(selection: selection) {
            ForEach(choices) { choice in
                Text(verbatim: choice.label).tag(choice.value)
            }
        } label: {
            Text(verbatim: info.title)
        }
        .labelsHidden()
        LabeledContent {
            if usesSegments {
                // Segments when they fit (Russian runs 15–35 % longer), a pop-up otherwise.
                ViewThatFits(in: .horizontal) {
                    picker.pickerStyle(.segmented).fixedSize()
                    picker.pickerStyle(.menu).fixedSize()
                }
            } else {
                picker.pickerStyle(.menu).fixedSize()
            }
        } label: {
            RowLabel(title: info.title, footnote: footnote)
        }
        .settingRow(info, isDefault: isDefault, reset: reset)
    }

    private var usesSegments: Bool {
        switch style {
        case .automatic: choices.count <= 4
        case .segmented: true
        case .menu: false
        }
    }
}

extension ChoiceRow where Value: Codable & Sendable {
    /// A picker bound to a settings key.
    init(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<Value>, choices: [Choice<Value>],
         footnote: String? = nil, style: ChoiceStyle = .automatic) {
        self.init(info: info, selection: settings.binding(key), choices: choices, footnote: footnote, style: style,
                  isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }
}

#Preview("Choice row") {
    let services = OverbrightServices.preview()
    Form {
        ChoiceRow(SettingsRowInfo(.shortcuts, "stepSize", title: "Step size"), settings: services.settings,
                  key: ShortcutSettings.stepSize,
                  choices: [Choice(value: StepSize.regular, label: "Regular"), Choice(value: StepSize.fine, label: "Fine")])
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 120)
}
