// OverbrightOnboarding/Chrome/WelcomeFooter.swift — the bottom row of every step (DESIGN.md §8): Quit Overbright
// bottom-leading, the progress dots, then Back (⌘[) and Continue (↩); the last step ends with Done, and with Turn On
// Overbright as the primary button when a display can boost. Ported from Cranny's WelcomeFooter (the owner's MIT code).
import Foundation
import OverbrightDesign
import SwiftUI

/// The Welcome window's footer.
struct WelcomeFooter: View {
    let session: WelcomeSession

    var body: some View {
        HStack(spacing: Space.m) {
            Button { session.quit() } label: { Text(verbatim: OnboardingCopy.quit) }
                .buttonStyle(OverbrightDesign.LinkButtonStyle())   // SwiftUI has a LinkButtonStyle too
            Spacer(minLength: Space.l)
            ProgressDots(current: session.stepNumber, count: session.stepCount)
            Spacer(minLength: Space.l)
            if session.canGoBack {
                Button { session.goBack() } label: {
                    Text("Back", bundle: .module, comment: "Welcome: returns to the previous step (title case; ⌘[ also works)")
                }
                .keyboardShortcut("[", modifiers: .command)
            }
            if session.isLastStep {
                if session.offersTurnOn {
                    Button { session.finish() } label: { Text(verbatim: OnboardingCopy.done) }
                    Button { session.finish(turningOn: true) } label: {
                        Text("Turn On Overbright", bundle: .module,
                             comment: "Welcome ▸ Done: primary button that ends setup and turns Overbright on (title case)")
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button { session.finish() } label: { Text(verbatim: OnboardingCopy.done) }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Button { session.goForward() } label: {
                    Text("Continue", bundle: .module, comment: "Welcome: goes to the next step (title case; Return also works)")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}
