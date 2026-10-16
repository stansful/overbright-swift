// OverbrightOnboarding/Chrome/WelcomeFooter.swift — the bottom row of every step (DESIGN.md §8): Quit Overbright
// bottom-leading, the progress dots, then Back (⌘[) and Continue (↩); the last step ends with Done, and with Turn On
// Overbright as the primary button when a display can boost. Ported from Cranny's WelcomeFooter (the owner's MIT code).
// The row must fit the window's width between its insets in every language (`WelcomeFooterFitTests`: English and the
// pseudo-long locale through `Labels`; every language in WP15). When long titles leave no room on the last step (Quit,
// Back, Done and Turn On Overbright), the progress dots step aside: the footer never truncates a button, and VoiceOver
// still hears the step from its header.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Welcome window's footer.
struct WelcomeFooter: View {
    let session: WelcomeSession
    /// The button titles: localized in the app; the fit tests pass longer ones.
    var labels = Labels.localized

    /// The footer's button titles.
    struct Labels {
        /// "Quit Overbright" (bottom-leading link).
        var quit: String
        /// "Back".
        var back: String
        /// "Continue".
        var proceed: String
        /// "Done".
        var done: String
        /// "Turn On Overbright".
        var turnOn: String

        /// The titles in the current language.
        static var localized: Labels { localized(in: .module) }

        /// The titles from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Labels {
            Labels(quit: OnboardingCopy.quit(in: bundle),
                   back: String(localized: "Back", bundle: bundle,
                                comment: "Welcome: returns to the previous step (title case; ⌘[ also works)"),
                   proceed: String(localized: "Continue", bundle: bundle,
                                   comment: "Welcome: goes to the next step (title case; Return also works)"),
                   done: OnboardingCopy.done(in: bundle),
                   turnOn: String(localized: "Turn On Overbright", bundle: bundle,
                                  comment: "Welcome ▸ Done: primary button that ends setup and turns Overbright on (title case)"))
        }

        /// Every title passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Labels {
            Labels(quit: transform(quit), back: transform(back), proceed: transform(proceed), done: transform(done),
                   turnOn: transform(turnOn))
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(showsDots: true)
            row(showsDots: false)
        }
        .controlSize(.large)
    }

    /// The row, with or without the progress dots (only the one that fits is shown, so its shortcuts are the live ones).
    func row(showsDots: Bool) -> some View {
        HStack(spacing: Space.m) {
            Button { session.quit() } label: { Text(verbatim: labels.quit) }
                .buttonStyle(OverbrightLinkButtonStyle())
            Spacer(minLength: Space.l)
            if showsDots {
                ProgressDots(current: session.stepNumber, count: session.stepCount)
                Spacer(minLength: Space.l)
            }
            if session.canGoBack {
                Button { session.goBack() } label: { Text(verbatim: labels.back) }
                    .keyboardShortcut("[", modifiers: .command)
            }
            if session.isLastStep {
                if session.offersTurnOn {
                    Button { session.finish() } label: { Text(verbatim: labels.done) }
                    Button { session.finish(turningOn: true) } label: { Text(verbatim: labels.turnOn) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button { session.finish() } label: { Text(verbatim: labels.done) }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                Button { session.goForward() } label: { Text(verbatim: labels.proceed) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

#Preview("Footer · first step") {
    WelcomeFooter(session: WelcomeSession(services: .preview(), recordsOutcome: false) { _ in })
        .padding(.horizontal, WelcomeMetrics.inset)
        .padding(.vertical, Space.xl)
        .frame(width: WelcomeMetrics.window.width)
}

#Preview("Footer · last step, Turn On") {
    let session = WelcomeSession(services: .preview(), initialStep: .done, recordsOutcome: false) { _ in }
    session.offersTurnOn = true
    return WelcomeFooter(session: session)
        .padding(.horizontal, WelcomeMetrics.inset)
        .padding(.vertical, Space.xl)
        .frame(width: WelcomeMetrics.window.width)
}
