// Controls/BoostToggleControl.swift — the Control Center toggle (DESIGN.md §12.8: title "Overbright", subtitle
// "Extra brightness"; symbols `sun.max` / `sun.max.fill`). ARCHITECTURE.md §7.7; D18.
import SwiftUI
import WidgetKit
import OverbrightChannel

/// The Control Center and menu bar toggle for extra brightness. Its kind (`BoostChannel.controlKind`) is a persisted
/// identifier: never rename it.
struct BoostToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: BoostChannel.controlKind, provider: BoostValueProvider()) { isOn in
            ControlWidgetToggle("Overbright", isOn: isOn, action: BoostControlIntent()) { isOn in
                Label("Extra brightness", systemImage: isOn ? "sun.max.fill" : "sun.max")
            }
        }
        .displayName("Overbright")
        .description("Extra brightness")
    }
}
