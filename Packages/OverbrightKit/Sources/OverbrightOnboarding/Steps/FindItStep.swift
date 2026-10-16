// OverbrightOnboarding/Steps/FindItStep.swift — Welcome step 4 Find it (DESIGN.md §8): the menu bar symbol, live key
// caps (`ShortcutCenter.displayString`), the Run Shortcut recipe.
// Seeded by WP0b with its headline only (ARCHITECTURE.md §10.2); WP12 owns this file and builds the step (§10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 4 Find it.
struct FindItStep: View {
    let session: WelcomeSession

    var body: some View {
        StepLayout {
            Color.clear
        } content: {
            StepHeader(title: String(localized: "Where to find Overbright", bundle: .module, comment: "Welcome ▸ Find it: headline"),
                       message: String(localized: "Overbright lives in the menu bar.",
                                       bundle: .module,
                                       comment: "Welcome ▸ Find it: body under the headline"))
        }
    }
}

#Preview("4 Find it") {
    FindItStep(session: WelcomeSession(services: .preview(), initialStep: .findIt) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
