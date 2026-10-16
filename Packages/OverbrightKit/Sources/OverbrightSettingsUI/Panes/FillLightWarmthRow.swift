// OverbrightSettingsUI/Panes/FillLightWarmthRow.swift — Fill Light ▸ Warmth (DESIGN.md §7.7): a slider from Cool to
// Warm with its value in kelvin ("5,100 K"), 6,500–3,000 K in whole steps of 100 K, stored as `fillLight.warmth`
// (0 … 1). The same `SliderRow` as Width and Brightness, with "Cool" and "Warm" under the ends of its track (WP14:
// beside the track they made it about 60 pt shorter than the others).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The warmth slider.
struct FillLightWarmthRow: View {
    let settings: SettingsStore

    var body: some View {
        SliderRow(FillLightRows.warmth, settings: settings, key: FillLightSettings.warmth, range: FillLightPane.warmthRange,
                  snap: Self.snapped, captions: Self.captions) { warmth in
            SettingsFormat.kelvin(PaneFormat.kelvin(warmth: warmth))
        }
    }

    /// "Cool" and "Warm" under the ends of the track.
    static var captions: SliderCaptions {
        SliderCaptions(minimum: String(localized: "Cool", bundle: .module,
                                       comment: "Settings ▸ Fill Light: the cool end of the Warmth slider"),
                       maximum: String(localized: "Warm", bundle: .module,
                                       comment: "Settings ▸ Fill Light: the warm end of the Warmth slider"))
    }

    /// `warmth` at the nearest whole 100 K (5,100 K is exactly the default 0.4 again).
    static func snapped(_ warmth: Double) -> Double {
        let kelvin = (PaneFormat.kelvin(warmth: warmth) / 100).rounded() * 100
        return (PaneFormat.coolKelvin - kelvin) / (PaneFormat.coolKelvin - PaneFormat.warmKelvin)
    }
}

#Preview("Warmth") {
    Form { FillLightWarmthRow(settings: OverbrightServices.preview().settings) }
        .formStyle(.grouped)
        .environment(SettingsNavigator(target: "fillLight"))
        .frame(width: 600, height: 100)
}
