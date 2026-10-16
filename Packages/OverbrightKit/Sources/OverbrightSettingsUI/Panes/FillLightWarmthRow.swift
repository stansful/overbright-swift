// OverbrightSettingsUI/Panes/FillLightWarmthRow.swift — Fill Light ▸ Warmth (DESIGN.md §7.7): a slider from Cool to
// Warm with its value in kelvin ("5,100 K"), 6,500–3,000 K in whole steps of 100 K, stored as `fillLight.warmth`
// (0 … 1).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The warmth slider.
struct FillLightWarmthRow: View {
    let settings: SettingsStore

    var body: some View {
        // Continuous (35 tick marks would crowd the track), settling on whole 100 K steps.
        let warmth = Binding<Double>(get: { settings[FillLightSettings.warmth] },
                                     set: { settings[FillLightSettings.warmth] = Self.snapped($0) })
        let kelvin = SettingsFormat.kelvin(PaneFormat.kelvin(warmth: warmth.wrappedValue))
        LabeledContent {
            HStack(spacing: Space.m) {
                Slider(value: warmth, in: FillLightPane.warmthRange) {
                    Text(verbatim: FillLightRows.warmth.title)
                } minimumValueLabel: {
                    Text("Cool", bundle: .module, comment: "Settings ▸ Fill Light: the cool end of the Warmth slider")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("Warm", bundle: .module, comment: "Settings ▸ Fill Light: the warm end of the Warmth slider")
                        .font(.caption)
                }
                .labelsHidden()
                .frame(minWidth: SettingsMetrics.sliderWidth.min, idealWidth: SettingsMetrics.sliderWidth.ideal,
                       maxWidth: SettingsMetrics.sliderWidth.max)
                .accessibilityValue(Text(verbatim: kelvin))
                Text(verbatim: kelvin)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: SettingsMetrics.sliderValueMinWidth, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        } label: {
            RowLabel(title: FillLightRows.warmth.title)
        }
        .settingRow(FillLightRows.warmth, settings: settings, key: FillLightSettings.warmth)
    }

    /// `warmth` at the nearest whole 100 K (5,100 K is exactly the default 0.4 again).
    static func snapped(_ warmth: Double) -> Double {
        let kelvin = (PaneFormat.kelvin(warmth: warmth) / 100).rounded() * 100
        return (PaneFormat.coolKelvin - kelvin) / (PaneFormat.coolKelvin - PaneFormat.warmKelvin)
    }
}
