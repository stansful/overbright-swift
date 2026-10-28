// Controls/OverbrightControls.swift — the dormant Control Center extension's entry point (sandboxed WidgetKit,
// macOS 26). ARCHITECTURE.md §7.7, D18, D25. It ships only with CONTROLS=1 (scripts/lib/build.sh) and links only the
// static OverbrightControlsKit product (= OverbrightChannel). No App Group, no network: it reads the app's state
// through notifyd and the app's preferences (read-only exception) and hands requests over through `overbright://`.
import SwiftUI
import WidgetKit

/// The extension's entry point.
@main
struct OverbrightControls: WidgetBundle {
    var body: some Widget {
        BoostToggleControl()
    }
}
