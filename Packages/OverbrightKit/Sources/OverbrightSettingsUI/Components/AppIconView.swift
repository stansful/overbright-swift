// OverbrightSettingsUI/Components/AppIconView.swift — the icon of an app row (the paused-apps editor and Advanced ▸ Other
// apps). Names and icons come from Core's `AppIdentityResolver`: looked up off the main actor, named by Finder, no icon
// read from a protected folder, and an explicit not-installed state. Ported from Cranny's AppIdentity.swift (the owner's
// MIT code).
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// A 20-pt app icon, or a dashed placeholder.
struct AppIconView: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: StrokeWidth.regular, dash: [Space.xxs]))
            }
        }
        .frame(width: SettingsMetrics.rowIcon, height: SettingsMetrics.rowIcon)
        .accessibilityHidden(true)
    }
}

#Preview("App icon") {
    let finder = AppIdentityResolver.shared.identity(of: "com.apple.finder")
    HStack {
        AppIconView(icon: finder.icon)
        Text(verbatim: finder.name ?? "")
    }
    .padding()
}
