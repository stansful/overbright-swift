// OverbrightOnboarding/Steps/HelloStep.swift — Welcome step 1 Hello (DESIGN.md §8): the before/after card
// (`EDRPreviewSurface`, registered with `OwnEDRSurfaces`, paused while the window is hidden) or the static
// illustration.
// Seeded by WP0b with its headline only (ARCHITECTURE.md §10.2); WP12 owns this file and builds the step (§10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 1 Hello.
struct HelloStep: View {
    let session: WelcomeSession
    /// Whether the window can be seen (the card pauses while it cannot).
    let isWindowVisible: Bool

    var body: some View {
        StepLayout {
            Color.clear
        } content: {
            StepHeader(title: String(localized: "Use your display’s extra range", bundle: .module, comment: "Welcome ▸ Hello: headline"),
                       message: String(localized: "Your display can show light brighter than ordinary white. Overbright lets everyday content use that range, so the screen stays readable in a bright room or in sunlight. For the most light, turn your display brightness all the way up first; Overbright adds to it. Drag the divider to compare.",
                                       bundle: .module,
                                       comment: "Welcome ▸ Hello: body under the headline"))
        }
    }
}

#Preview("1 Hello") {
    HelloStep(session: WelcomeSession(services: .preview(), initialStep: .hello) { _ in }, isWindowVisible: true)
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
