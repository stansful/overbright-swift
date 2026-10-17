// OverbrightOnboardingTests/WelcomeChromeSnapshotTests.swift — the Welcome chrome WP0b delivers (DESIGN.md §8, §12.4) in
// Light, Dark and Increase Contrast (ARCHITECTURE.md §9.1, §9.3 #5): the footer on the first, a middle and the last step
// (with and without Turn On Overbright), the whole window on step 1, and the "Skip setup?" alert with its three
// buttons. Steps are seeded (WP12 fills and snapshots them). Rendered in-process, never ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeChromeSnapshotTests {
    /// A session at `step` that records nothing.
    static func session(_ step: WelcomeStep, turnOn: Bool = false) -> WelcomeSession {
        let session = WelcomeSession(services: .preview(), initialStep: step, recordsOutcome: false) { _ in }
        session.offersTurnOn = turnOn
        return session
    }

    /// The footer as the window lays it out: between the window's side insets.
    static func footer(_ session: WelcomeSession, labels: WelcomeFooter.Labels = .localized) -> some View {
        WelcomeFooter(session: session, labels: labels)
            .inWindow
            .frame(width: WelcomeMetrics.window.width)
    }

    @Test(arguments: ChromeAppearance.allCases)
    func theFooterRendersOnEveryKindOfStep(_ appearance: ChromeAppearance) throws {
        let footers: [(String, WelcomeSession)] = [
            ("footer-first", Self.session(.hello)), ("footer-middle", Self.session(.defaults)),
            ("footer-last", Self.session(.done)), ("footer-last-turn-on", Self.session(.done, turnOn: true)),
        ]
        for (name, session) in footers {
            let rep = try ChromeSnapshot.render(Self.footer(session), appearance)
            #expect(CGFloat(rep.pixelsWide) >= WelcomeMetrics.window.width, "\(name)")
            #expect(ChromeSnapshot.inkFraction(rep) > 0.003, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }

    /// The last step in the pseudo-long locale: the dots stay centred above the buttons, every button stays whole.
    @Test(arguments: ChromeAppearance.allCases)
    func theLongLastFooterKeepsItsButtons(_ appearance: ChromeAppearance) throws {
        let long = WelcomeFooterFitTests.english.map(PseudoLocale.lengthen)
        let rep = try ChromeSnapshot.render(Self.footer(Self.session(.done, turnOn: true), labels: long), appearance)
        #expect(CGFloat(rep.pixelsWide) >= WelcomeMetrics.window.width)
        #expect(ChromeSnapshot.inkFraction(rep) > 0.003, "\(appearance.rawValue): nothing drawn")
        try ChromeSnapshot.write(rep, "footer-last-turn-on-pseudo-long", appearance)
    }

    @Test(arguments: ChromeAppearance.allCases)
    func theWindowRendersOnTheFirstStep(_ appearance: ChromeAppearance) throws {
        let view = WelcomeView(session: Self.session(.hello)).environment(\.isStaticSnapshot, true)
        let rep = try ChromeSnapshot.render(view, appearance, size: WelcomeMetrics.window)
        #expect(CGFloat(rep.pixelsWide) >= WelcomeMetrics.window.width)
        #expect(ChromeSnapshot.inkFraction(rep) > 0.005, "\(appearance.rawValue): nothing drawn")
        try ChromeSnapshot.write(rep, "window-hello", appearance)
    }

    /// "Skip setup?" [Skip] [Continue Setup] [Quit Overbright], with the copy SwiftUI's alert shows.
    @Test(arguments: ChromeAppearance.allCases)
    func theSkipAlertRenders(_ appearance: ChromeAppearance) throws {
        let rep = try ChromeSnapshot.renderAlert(
            title: OnboardingCopy.skipTitle, message: OnboardingCopy.skipMessage,
            buttons: [OnboardingCopy.skip, OnboardingCopy.continueSetup, OnboardingCopy.quit], appearance)
        #expect(rep.pixelsWide > 200 && rep.pixelsHigh > 100)
        #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(appearance.rawValue): nothing drawn")
        try ChromeSnapshot.write(rep, "skip-alert", appearance)
    }

    @Test func darkAndLightDiffer() throws {
        let light = try ChromeSnapshot.render(Self.footer(Self.session(.hello)), .light)
        let dark = try ChromeSnapshot.render(Self.footer(Self.session(.hello)), .dark)
        #expect(ChromeSnapshot.backgroundBrightness(light) > ChromeSnapshot.backgroundBrightness(dark) + 0.3)
        let buttons = [OnboardingCopy.skip, OnboardingCopy.continueSetup, OnboardingCopy.quit]
        let lightAlert = try ChromeSnapshot.renderAlert(title: OnboardingCopy.skipTitle, message: OnboardingCopy.skipMessage,
                                                        buttons: buttons, .light)
        let darkAlert = try ChromeSnapshot.renderAlert(title: OnboardingCopy.skipTitle, message: OnboardingCopy.skipMessage,
                                                       buttons: buttons, .dark)
        #expect(ChromeSnapshot.backgroundBrightness(lightAlert) > ChromeSnapshot.backgroundBrightness(darkAlert) + 0.3)
    }
}
