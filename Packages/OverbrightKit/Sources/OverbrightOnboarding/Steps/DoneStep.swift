// OverbrightOnboarding/Steps/DoneStep.swift — Welcome step 5 Done (DESIGN.md §8): the Check for updates on GitHub
// switch (only when `WelcomePlan.showsUpdateToggle`) and `offersTurnOn`.
// Seeded by WP0b with its headline only (ARCHITECTURE.md §10.2); WP12 owns this file and builds the step (§10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 5 Done.
struct DoneStep: View {
    let session: WelcomeSession

    var body: some View {
        StepLayout {
            Color.clear
        } content: {
            StepHeader(title: String(localized: "You’re set", bundle: .module, comment: "Welcome ▸ Done: headline"))
        }
    }
}

#Preview("5 Done") {
    DoneStep(session: WelcomeSession(services: .preview(), initialStep: .done) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
