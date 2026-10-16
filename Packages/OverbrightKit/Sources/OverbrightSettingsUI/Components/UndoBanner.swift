// OverbrightSettingsUI/Components/UndoBanner.swift — "All settings were reset." [Undo] after Reset All (DESIGN.md §7.8,
// §12.4), floating at the bottom of the window for 10 s. VoiceOver hears it once per offer, also when Settings is
// closed and opened again while the banner lasts. ⌘Z is the root view's (it works until the window closes). Ported
// from Cranny's UndoBanner (the owner's MIT code).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Reset All banner.
struct UndoBanner: View {
    let controller: ResetAllController

    var body: some View {
        HStack(spacing: Space.l) {
            Image(symbol: .arrowCounterclockwise)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("All settings were reset.", bundle: .module, comment: "Settings: banner after Reset All Settings")
            Button {
                controller.undo()
            } label: {
                Text("Undo", bundle: .module, comment: "Settings: banner button that restores the settings from before Reset All (title case)")
            }
            Button {
                controller.dismissBanner()
            } label: {
                Image(symbol: .xmark)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Dismiss", bundle: .module,
                                     comment: "VoiceOver: close button of the Reset All banner in Settings"))
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.m)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(.separator))
        .accessibilityElement(children: .contain)
        .onAppear {
            guard controller.takeAnnouncement() else { return }
            AccessibilityNotification.Announcement(
                String(localized: "All settings were reset. Undo is available until you close Settings.", bundle: .module,
                       comment: "VoiceOver: announcement after Reset All Settings")).post()
        }
    }
}

#Preview("Undo banner") {
    UndoBanner(controller: ResetAllController(services: .preview()))
        .padding(Space.huge)
}
