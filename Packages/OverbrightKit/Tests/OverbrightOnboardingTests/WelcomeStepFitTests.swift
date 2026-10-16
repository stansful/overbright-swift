// OverbrightOnboardingTests/WelcomeStepFitTests.swift — every step's copy and controls fit the fixed 640 × 480 window
// (DESIGN.md §8; §16: "constrained strings are measured … English and a pseudo-long locale during development, all 35
// in WP15"; ARCHITECTURE.md §9.1 UI row). Measured, never counted: the heights SwiftUI lays out at the window's width.
// The lower half (the step's header and controls) must fit between the stage and the footer; the stage's own controls
// (step 3's switches, step 4's menu bar and key caps) must fit the stage; step 1's card is sized by the stage. Step 2
// uses the whole page: with the owner's two displays and with three, every row shows at once under Design's real
// verdict words, in English and pseudo-long; with more than fit, the rows scroll, with every row in the scroll view.
// WP15 runs the steps, the stage and step 2's rows in every language Overbright ships (`everyStepFitsInEveryLanguage`).
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeStepFitTests {
    /// The width of the lower half and of the stage's content: the window minus its side insets.
    static let width = WelcomeMetrics.window.width - 2 * WelcomeMetrics.inset

    /// The height of a step's page: the window minus the footer (as `WelcomeView` pads it).
    static var pageHeight: CGFloat {
        let session = WelcomeSession(services: .preview(), initialStep: .defaults, recordsOutcome: false) { _ in }
        let footer = FitMeasure.height(WelcomeFooter(session: session).padding(.vertical, Space.xl),
                                       width: WelcomeMetrics.window.width)
        return WelcomeMetrics.window.height - footer
    }

    /// The height of the lower half: the page minus the stage, its divider and the content's top padding.
    static var lowerBudget: CGFloat {
        pageHeight - WelcomeMetrics.stageHeight - StrokeWidth.regular - Space.xl
    }

    /// A step's lower half as `StepLayout` stacks it.
    static func lower(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.l) { content() }
    }

    /// The lower half of every step with `transform` applied to its words from `bundle` (English by default).
    static func lowers(in bundle: Bundle = englishBundle,
                       _ transform: @escaping (String) -> String) -> [(String, AnyView)] {
        let services = WelcomePreview.services(updatesConfigured: true)
        let choices = WelcomeChoices()
        let hello = HelloStep.Copy.localized(in: bundle).map(transform)
        let defaults = DefaultsStep.Copy.localized(in: bundle).map(transform)
        let findIt = FindItStep.Copy.localized(in: bundle).map(transform)
        let done = DoneStep.Copy.localized(in: bundle).map(transform)
        return [
            ("hello", AnyView(lower { HelloLower(copy: hello, card: .preview(display: DisplayFixture.Keys.builtIn,
                                                                               gain: 1.29)) })),
            ("hello-none", AnyView(lower { HelloLower(copy: hello, card: .noneCapable) })),
            ("defaults", AnyView(lower {
                StepHeader(title: defaults.title, message: defaults.message)
                LoginOptions(choices: choices, settings: services.settings, copy: defaults)
            })),
            ("findIt", AnyView(lower {
                StepHeader(title: findIt.title, message: findIt.message)
                FindItLower(copy: findIt)
            })),
            ("done", AnyView(lower {
                StepHeader(title: done.title)
                UpdateSwitch(choices: choices, settings: services.settings, copy: done)
            })),
        ]
    }

    /// The stage content of steps 3 and 4 with `transform` applied to its words from `bundle` (English by default).
    static func stages(in bundle: Bundle = englishBundle,
                       _ transform: @escaping (String) -> String) -> [(String, AnyView)] {
        let services = WelcomePreview.services()
        let defaults = DefaultsStep.Copy.localized(in: bundle).map(transform)
        let findIt = FindItStep.Copy.localized(in: bundle).map(transform)
        return [
            ("defaults", AnyView(GuardSwitches(choices: WelcomeChoices(), settings: services.settings, copy: defaults))),
            ("findIt", AnyView(FindItStage(shortcuts: FindItShortcut.rows(services.shortcuts), copy: findIt)
                .fixedSize(horizontal: false, vertical: true))),
        ]
    }

    @Test func theLowerHalfFitsInEnglish() {
        let budget = Self.lowerBudget
        #expect(budget > 150 && budget < 260)                                    // the window's own arithmetic
        for (name, view) in Self.lowers({ $0 }) {
            let height = FitMeasure.height(view, width: Self.width)
            #expect(height > 0 && height <= budget, "\(name): \(height) pt of \(budget)")
        }
    }

    @Test func theLowerHalfFitsInThePseudoLongLocale() {
        let budget = Self.lowerBudget
        for (name, view) in Self.lowers(PseudoLocale.lengthen) {
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
            let budget = Self.pageHeight - StepMetrics.titleBarInset - header - Space.l
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
        let budget = Self.lowerBudget
        for (name, view) in Self.lowers(in: bundle, { $0 }) {
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
            let rowBudget = Self.pageHeight - StepMetrics.titleBarInset - header - Space.l
            #expect(list > 0 && list <= rowBudget, "\(code), \(count) displays: \(list) pt of \(rowBudget)")
            let session = WelcomeSession(services: services, initialStep: .displays, recordsOutcome: false) { _ in }
            let window = Self.window(DisplaysStep(session: session, copy: copy))
            let host = try #require(window.contentView)
            #expect(scrollViews(in: host).isEmpty, "\(code), \(count) displays: the rows scroll")
            window.contentView = nil
        }
    }
}
