// OverbrightOnboarding/Steps/DisplaysStep.swift — Welcome step 2 Displays (DESIGN.md §8): one row per display with its
// verdict, fix and Use extra brightness switch, re-evaluated when displays change.
// Seeded by WP0b with its headline only (ARCHITECTURE.md §10.2); WP12 owns this file and builds the step (§10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 2 Displays.
struct DisplaysStep: View {
    let session: WelcomeSession

    var body: some View {
        StepLayout {
            Color.clear
        } content: {
            StepHeader(title: String(localized: "Your displays", bundle: .module, comment: "Welcome ▸ Displays: headline"),
                       message: String(localized: "Overbright checks what each display can do.",
                                       bundle: .module,
                                       comment: "Welcome ▸ Displays: body under the headline"))
        }
    }
}

#Preview("2 Displays") {
    DisplaysStep(session: WelcomeSession(services: .preview(), initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
