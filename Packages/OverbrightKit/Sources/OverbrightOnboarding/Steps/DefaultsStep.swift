// OverbrightOnboarding/Steps/DefaultsStep.swift — Welcome step 3 Defaults (DESIGN.md §8): the guard switches and the
// three login option cards (`SelectableCardStyle`).
// Seeded by WP0b with its headline only (ARCHITECTURE.md §10.2); WP12 owns this file and builds the step (§10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 3 Defaults.
struct DefaultsStep: View {
    let session: WelcomeSession

    var body: some View {
        StepLayout {
            Color.clear
        } content: {
            StepHeader(title: String(localized: "How Overbright behaves", bundle: .module, comment: "Welcome ▸ Defaults: headline"),
                       message: String(localized: "Extra light uses more power, so Overbright steps back on its own. Choose how it starts.",
                                       bundle: .module,
                                       comment: "Welcome ▸ Defaults: body under the headline"))
        }
    }
}

#Preview("3 Defaults") {
    DefaultsStep(session: WelcomeSession(services: .preview(), initialStep: .defaults) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
