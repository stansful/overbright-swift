// OverbrightOnboardingTests/WelcomeStepFitTests.swift — every step's copy and controls fit the fixed 640 × 480 window
// (DESIGN.md §8; §16: "constrained strings are measured … English and a pseudo-long locale during development, all 35
// in WP15"; ARCHITECTURE.md §9.1 UI row). Measured, never counted: the heights SwiftUI lays out at the window's width.
// The lower half (the step's header and controls) must fit between the stage and the footer: under the full stage on
// steps 1, 4 and 5, under the compact stage on steps 2 and 3 (`StageSize`, WP14 C-ONBOARD-1), and on step 5 above the
// footer with Turn On Overbright, whose progress dots take a line of their own in English; step 4's stage content
// (the menu bar and key caps) must fit the stage; step 1's card is sized by the stage. Step 2: with the owner's two
// displays and with three, every row shows at once under Design's real verdict words, in English and pseudo-long;
// with more than fit, the rows scroll, with every row in the scroll view. WP15 runs the steps, the stage and step 2's
// rows in every language Overbright ships (`everyStepFitsInEveryLanguage`).
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeStepFitTests {
    /// The width of the lower half and of the stage's content: the window minus its side insets.
    static let width = WelcomeMetrics.window.width - 2 * WelcomeMetrics.inset

    /// The height of a step's page: the window minus the footer as `WelcomeView` places it, with the progress dots in
    /// its row (every step but the last one with Turn On Overbright, `WelcomeFooterFitTests`).
    static var pageHeight: CGFloat { pageHeight(under: WelcomeChromeSnapshotTests.session(.defaults)) }

    /// The page of the last step with Turn On Overbright, whose footer puts the dots on their own line above its
    /// buttons in English (no other footer does, in any language): a line shorter. Step 5 is measured under it.
    static var lastPageHeight: CGFloat { pageHeight(under: WelcomeChromeSnapshotTests.session(.done, turnOn: true)) }

    /// The window minus the footer of `session` in English.
    static func pageHeight(under session: WelcomeSession) -> CGFloat {
        let footer = WelcomeFooter(session: session, labels: WelcomeFooterFitTests.english).inWindow
        return WelcomeMetrics.window.height - FitMeasure.height(footer, width: WelcomeMetrics.window.width)
    }

    /// The height of the lower half under a stage of `size`: the page (`page`) minus the stage, its divider and the
    /// copy's top padding.
    static func lowerBudget(_ size: StageSize, page: CGFloat = pageHeight) -> CGFloat {
        page - size.headlineTop
    }

    /// A step's lower half as `StepLayout` stacks it.
    static func lower(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.l) { content() }
    }

    /// The lower half of every step with `transform` applied to its words from `bundle` (English by default), and the
    /// height it has: under the stage it sits under, and above the footer of its step (step 5's has Turn On
    /// Overbright, the tallest footer). Step 2's is measured with its rows, `stepTwoShowsEveryRowAtOnce`.
    static func lowers(in bundle: Bundle = englishBundle,
                       _ transform: @escaping (String) -> String) -> [(String, CGFloat, AnyView)] {
        let services = WelcomePreview.services(updatesConfigured: true)
        let choices = WelcomeChoices()
        let hello = HelloStep.Copy.localized(in: bundle).map(transform)
        let defaults = DefaultsStep.Copy.localized(in: bundle).map(transform)
        let findIt = FindItStep.Copy.localized(in: bundle).map(transform)
        let done = DoneStep.Copy.localized(in: bundle).map(transform)
        return [
            ("hello", lowerBudget(.regular), AnyView(lower {
                HelloLower(copy: hello, card: .preview(display: DisplayFixture.Keys.builtIn, gain: 1.29))
            })),
            ("hello-none", lowerBudget(.regular), AnyView(lower { HelloLower(copy: hello, card: .noneCapable) })),
            ("hello-other-display", lowerBudget(.regular), AnyView(lower {
                HelloLower(copy: hello, card: .otherDisplay)
            })),
            ("defaults", lowerBudget(.compact), AnyView(lower {
                StepHeader(title: defaults.title, message: defaults.message)
                GuardSwitches(choices: choices, settings: services.settings, copy: defaults)
                LoginOptions(choices: choices, settings: services.settings, copy: defaults)
            })),
            ("findIt", lowerBudget(.regular), AnyView(lower {
                StepHeader(title: findIt.title, message: findIt.message)
                FindItLower(copy: findIt)
            })),
            ("done", lowerBudget(.regular, page: lastPageHeight), AnyView(lower {
                StepHeader(title: done.title)
                DoneSummary(choices: choices, settings: services.settings, copy: done.summary)
                UpdateSwitch(choices: choices, settings: services.settings, copy: done)
            })),
        ]
    }

    /// The stage content of step 4 with `transform` applied to its words from `bundle` (English by default).
    static func stages(in bundle: Bundle = englishBundle,
                       _ transform: @escaping (String) -> String) -> [(String, AnyView)] {
        let services = WelcomePreview.services()
        let findIt = FindItStep.Copy.localized(in: bundle).map(transform)
        return [
            ("findIt", AnyView(FindItStage(shortcuts: FindItShortcut.rows(services.shortcuts), copy: findIt)
                .fixedSize(horizontal: false, vertical: true))),
        ]
    }

    @Test func theLowerHalfFitsInEnglish() {
        #expect(Self.lowerBudget(.regular) > 150 && Self.lowerBudget(.regular) < 260)   // the window's own arithmetic
        #expect(Self.lowerBudget(.compact) > 300 && Self.lowerBudget(.compact) < 400)
        for (name, budget, view) in Self.lowers({ $0 }) {
            let height = FitMeasure.height(view, width: Self.width)
            #expect(height > 0 && height <= budget, "\(name): \(height) pt of \(budget)")
        }
    }

    @Test func theLowerHalfFitsInThePseudoLongLocale() {
        for (name, budget, view) in Self.lowers(PseudoLocale.lengthen) {
            let height = FitMeasure.height(view, width: Self.width)
            #expect(height <= budget, "\(name), pseudo-long: \(height) pt of \(budget)")
        }
    }

    @Test func theStageControlsFitTheStage() {
        for transform in [{ (text: String) in text }, PseudoLocale.lengthen] {
            for (name, view) in Self.stages(transform) {
                let height = FitMeasure.height(view, width: Self.width)
                #expect(height > 0 && height <= StepMetrics.stageContentHeight,
                        "\(name): \(height) pt of \(StepMetrics.stageContentHeight)")
            }
        }
    }

    // MARK: Step 2

    /// The two ways step 2's words are measured: English and the pseudo-long locale.
    static var languages: [(name: String, transform: (String) -> String)] {
        [("English", { $0 }), ("pseudo-long", PseudoLocale.lengthen)]
    }

    /// Step 2's words in English through `transform`, the verdicts' words included.
    static func displaysCopy(_ transform: @escaping (String) -> String) -> DisplaysStep.Copy {
        var copy = DisplaysStep.Copy.localized(in: englishBundle)
        copy.verdictLanguage = .english()
        return copy.map(transform)
    }

    /// The window `page` lays out in: the page's own size (window minus footer), never ordered in.
    static func window(_ page: some View) -> NSWindow {
        let size = CGSize(width: WelcomeMetrics.window.width, height: pageHeight)
        let host = NSHostingView(rootView: page.environment(\.isStaticSnapshot, true).overbrightThemeRoot()
            .frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return window
    }

    /// The owner's two displays (`.russianNames`: the built-in XDR and the MPG322UX OLED) and three (plus a Studio
    /// Display XDR, the longest verdict): every row shows at once, without scrolling, in English and pseudo-long.
    @Test(arguments: [2, 3])
    func stepTwoShowsEveryRowAtOnce(_ count: Int) throws {
        let services = count == 2 ? WelcomePreview.services(.russianNames) : WelcomePreview.threeDisplays
        for language in Self.languages {
            let copy = Self.displaysCopy(language.transform)
            let rows = WelcomeDisplayRow.rows(in: services, language: .english()).map { $0.map(language.transform) }
            try #require(rows.count == count)
            let header = FitMeasure.height(StepHeader(title: copy.title, message: copy.message), width: Self.width)
            let list = FitMeasure.height(DisplayRowList(rows: rows, switchTitle: copy.useExtraBrightness,
                                                        actions: WelcomeDisplayActions(services: services,
                                                                                       choices: WelcomeChoices())),
                                         width: Self.width)
            let budget = Self.lowerBudget(.compact) - header - Space.l
            #expect(list > 0 && list <= budget, "\(count) displays, \(language.name): \(list) pt of \(budget)")

            let session = WelcomeSession(services: services, initialStep: .displays, recordsOutcome: false) { _ in }
            let window = Self.window(DisplaysStep(session: session, copy: copy))
            let host = try #require(window.contentView)
            #expect(scrollViews(in: host).isEmpty, "\(count) displays, \(language.name): the rows scroll")
            window.contentView = nil
            let size = CGSize(width: WelcomeMetrics.window.width, height: Self.pageHeight)
            let rep = try ChromeSnapshot.render(DisplaysStep(session: session, copy: copy)
                .environment(\.isStaticSnapshot, true), .light, size: size)
            try ChromeSnapshot.write(rep, "page-displays-\(count)-\(language.name)", .light)
        }
    }

    /// More displays than fit (five, pseudo-long): the rows scroll, and every row is in the scroll view.
    @Test func stepTwoScrollsWhenTheRowsDoNotFit() throws {
        let services = WelcomePreview.services(.russianNames, adding: DisplayFixture.studioDisplayXDR.displays
                                               + DisplayFixture.proDisplayXDR.displays
                                               + DisplayFixture.sidecar.displays.filter { !$0.facts.isBuiltIn })
        let transform = PseudoLocale.lengthen
        let copy = Self.displaysCopy(transform)
        let rows = WelcomeDisplayRow.rows(in: services, language: .english()).map { $0.map(transform) }
        try #require(rows.count == 5)
        let list = FitMeasure.height(DisplayRowList(rows: rows, switchTitle: copy.useExtraBrightness,
                                                    actions: WelcomeDisplayActions(services: services,
                                                                                   choices: WelcomeChoices())),
                                     width: Self.width)
        let session = WelcomeSession(services: services, initialStep: .displays, recordsOutcome: false) { _ in }
        let window = Self.window(DisplaysStep(session: session, copy: copy))
        let host = try #require(window.contentView)
        let scroll = try #require(scrollViews(in: host).first, "five rows do not fit: they scroll")
        let content = try #require(scroll.documentView).frame.height
        #expect(content > scroll.contentView.bounds.height, "\(content) pt in \(scroll.contentView.bounds.height)")
        #expect(content >= list, "every row is in the scroll view: \(content) pt for \(list)")
        window.contentView = nil
    }

    /// The login cards share the width: no card is pushed out of the window by a long translation.
    @Test func theLoginCardsStayInTheWindow() {
        let services = WelcomePreview.services()
        for transform in [{ (text: String) in text }, PseudoLocale.lengthen] {
            let copy = DefaultsStep.Copy.localized(in: englishBundle).map(transform)
            let width = FitMeasure.width(LoginOptions(choices: WelcomeChoices(), settings: services.settings, copy: copy),
                                         offered: Self.width)
            #expect(width <= Self.width, "\(width) pt of \(Self.width)")
        }
    }

    // MARK: Every language (WP15)

    /// In every language Overbright ships: every step's lower half fits between the stage and the footer, the stage's
    /// controls fit the stage, the login cards stay in the window, and step 2 shows two and three displays at once
    /// under the language's own verdict words.
    @Test(arguments: CopyLanguage.available)
    func everyStepFitsInEveryLanguage(_ code: String) throws {
        let bundle = onboardingBundle(code)
        for (name, budget, view) in Self.lowers(in: bundle, { $0 }) {
            let height = FitMeasure.height(view, width: Self.width)
            #expect(height > 0 && height <= budget, "\(code), \(name): \(height) pt of \(budget)")
        }
        for (name, view) in Self.stages(in: bundle, { $0 }) {
            let height = FitMeasure.height(view, width: Self.width)
            #expect(height > 0 && height <= StepMetrics.stageContentHeight,
                    "\(code), \(name): \(height) pt of \(StepMetrics.stageContentHeight)")
        }
        let services = WelcomePreview.services()
        let login = FitMeasure.width(LoginOptions(choices: WelcomeChoices(), settings: services.settings,
                                                  copy: DefaultsStep.Copy.localized(in: bundle)), offered: Self.width)
        #expect(login <= Self.width, "\(code), login cards: \(login) pt of \(Self.width)")

        let language = CopyLanguage.named(code) ?? .english()
        var copy = DisplaysStep.Copy.localized(in: bundle)
        copy.verdictLanguage = language
        for count in [2, 3] {
            let services = count == 2 ? WelcomePreview.services(.russianNames) : WelcomePreview.threeDisplays
            let rows = WelcomeDisplayRow.rows(in: services, language: language)
            try #require(rows.count == count)
            let header = FitMeasure.height(StepHeader(title: copy.title, message: copy.message), width: Self.width)
            let list = FitMeasure.height(DisplayRowList(rows: rows, switchTitle: copy.useExtraBrightness,
                                                        actions: WelcomeDisplayActions(services: services,
                                                                                       choices: WelcomeChoices())),
                                         width: Self.width)
            let rowBudget = Self.lowerBudget(.compact) - header - Space.l
            #expect(list > 0 && list <= rowBudget, "\(code), \(count) displays: \(list) pt of \(rowBudget)")
            let session = WelcomeSession(services: services, initialStep: .displays, recordsOutcome: false) { _ in }
            let window = Self.window(DisplaysStep(session: session, copy: copy))
            let host = try #require(window.contentView)
            #expect(scrollViews(in: host).isEmpty, "\(code), \(count) displays: the rows scroll")
            window.contentView = nil
        }
    }
}
