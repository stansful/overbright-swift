// Controls/OverbrightControls.swift — the dormant Control Center extension (sandboxed WidgetKit, macOS 26).
// ARCHITECTURE.md §7.7, D18, D25. It ships only with CONTROLS=1 (scripts/build.sh) and links only the static
// OverbrightControlsKit product (= OverbrightChannel).
// Placeholder written by WP0a so that the target builds; its owner (WP8) adds the value provider with the liveness
// gate, the localized strings and the state channel.
import AppIntents
import SwiftUI
import WidgetKit
import OverbrightChannel

/// The extension's entry point.
@main
struct OverbrightControls: WidgetBundle {
    var body: some Widget {
        BoostToggleControl()
    }
}

/// The Control Center toggle for extra brightness. The `kind` is a persisted identifier: never rename it.
struct BoostToggleControl: ControlWidget {
    static let kind = "app.overbright.Overbright.BoostToggle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle("Extra Brightness", isOn: false, action: BoostControlIntent()) { isOn in
                Label(isOn ? "On" : "Off", systemImage: isOn ? "sun.max.fill" : "sun.max")
            }
        }
        .displayName("Overbright")
        .description("Extra brightness")
    }
}
