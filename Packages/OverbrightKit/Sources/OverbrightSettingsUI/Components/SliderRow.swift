// OverbrightSettingsUI/Components/SliderRow.swift — a slider row that always shows its value with its unit (DESIGN.md
// §7.2: "sliders always show their value with its unit and ticks at meaningful stops"). Ported from Cranny's
// SettingControls.swift (the owner's MIT code).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// A slider row: label on the leading side, the slider and its formatted value.
struct SliderRow: View {
    let info: SettingsRowInfo
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    /// "48 pt", "5,100 K", "80 %": the value with its unit, always shown.
    let format: (Double) -> String
    var footnote: String?
    let isDefault: Bool
    let reset: @MainActor () -> Void
    var onEditingChanged: @MainActor (Bool) -> Void = { _ in }

    var body: some View {
        LabeledContent {
            HStack(spacing: Space.m) {
                Slider(value: value, in: range, step: step) {
                    Text(verbatim: info.title)
                } onEditingChanged: { editing in
                    onEditingChanged(editing)
                }
                .labelsHidden()
                .frame(minWidth: 140, idealWidth: 200, maxWidth: 220)
                .accessibilityValue(Text(verbatim: format(value.wrappedValue)))
                Text(verbatim: format(value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        } label: {
            RowLabel(title: info.title, footnote: footnote)
        }
        .settingRow(info, isDefault: isDefault, reset: reset)
    }
}

extension SliderRow {
    /// A slider bound to a Double key.
    init(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<Double>, range: ClosedRange<Double>,
         step: Double, footnote: String? = nil, format: @escaping (Double) -> String) {
        self.init(info: info, value: settings.binding(key), range: range, step: step, format: format,
                  footnote: footnote, isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }
}

#Preview("Slider row") {
    let services = OverbrightServices.preview()
    Form {
        SliderRow(SettingsRowInfo(.fillLight, "width", title: "Width"), settings: services.settings,
                  key: FillLightSettings.width, range: 16...120, step: 4) { SettingsFormat.points($0) }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 120)
}
