// OverbrightOnboarding/Chrome/WelcomeFooter.swift — the bottom row of every step (DESIGN.md §8): Quit Overbright
// bottom-leading, Back (⌘[) and Continue (↩) trailing; the last step ends with Done, and with Turn On Overbright as the
// primary button when a display can boost. The progress dots sit in the centre of the window, whatever the widths of
// the two button groups (`CentredRow`), so they stay in one place from step to step (WP14 C-ONBOARD-1; they drifted
// with the buttons between two spacers). Ported from Cranny's WelcomeFooter (the owner's MIT code). The row must fit
// the window's width between its insets in every language (`WelcomeFooterFitTests`: English, the pseudo-long locale
// and every shipped language). When a button group would reach the centre (the last step with Turn On Overbright:
// Back, Done and Turn On Overbright), the progress dots step aside: the footer never truncates a button or moves the
// dots off centre, and VoiceOver still hears the step from its header.
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

    /// The row, with the progress dots centred in it or without them (only the one that fits is shown, so its
    /// shortcuts are the live ones).
    @ViewBuilder func row(showsDots: Bool) -> some View {
        if showsDots {
            CentredRow(spacing: Space.l) {
                quitButton
                ProgressDots(current: session.stepNumber, count: session.stepCount)
                buttons
            }
        } else {
            HStack(spacing: Space.m) {
                quitButton
                Spacer(minLength: Space.l)
                buttons
            }
        }
    }

    /// Quit Overbright, bottom-leading.
    private var quitButton: some View {
        Button { session.quit() } label: { Text(verbatim: labels.quit) }
            .buttonStyle(OverbrightLinkButtonStyle())
    }

    /// Back and Continue, or Back, Done and Turn On Overbright on the last step.
    private var buttons: some View {
        HStack(spacing: Space.m) {
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

/// Three views in a row: the first at the leading edge, the last at the trailing edge, and the middle one centred in
/// the row whatever the widths of the other two. Every view takes its ideal size (no button is ever truncated). Its
/// ideal width keeps the middle view `spacing` clear of the wider side on both sides, so in a `ViewThatFits` the row
/// gives way as soon as a side would reach the centre. SwiftUI mirrors it for right-to-left languages.
struct CentredRow: Layout {
    /// The least space between the middle view and either side.
    var spacing: CGFloat

    /// The width the row needs: twice the wider side, the middle view, and `spacing` on both sides of it.
    static func idealWidth(leading: CGFloat, middle: CGFloat, trailing: CGFloat, spacing: CGFloat) -> CGFloat {
        2 * max(leading, trailing) + middle + 2 * spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let ideal = Self.idealWidth(leading: sizes[0].width, middle: sizes[1].width, trailing: sizes[2].width,
                                    spacing: spacing)
        let width = proposal.width.flatMap { $0.isFinite ? max($0, ideal) : nil } ?? ideal
        return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)
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
