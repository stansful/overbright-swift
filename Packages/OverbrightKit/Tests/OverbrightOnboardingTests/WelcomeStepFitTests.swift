// OverbrightOnboardingTests/WelcomeStepFitTests.swift — every step's copy and controls fit the fixed 640 × 480 window
// (DESIGN.md §8; §16: "constrained strings are measured … English and a pseudo-long locale during development, all 35
// in WP15"; ARCHITECTURE.md §9.1 UI row). Measured, never counted: the heights SwiftUI lays out at the window's width.
// The lower half (the step's header and controls) must fit between the stage and the footer; the stage's own controls
// (step 3's switches, step 4's menu bar and key caps) must fit the stage. Step 2's rows scroll on the stage, and step
// 1's card is sized by the stage.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeStepFitTests {
    /// The width of the lower half and of the stage's content: the window minus its side insets.
    static let width = WelcomeMetrics.window.width - 2 * WelcomeMetrics.inset

    /// The height of the lower half: the window minus the stage, its divider, the content's top padding and the footer.
    static var lowerBudget: CGFloat {
        let session = WelcomeSession(services: .preview(), initialStep: .defaults, recordsOutcome: false) { _ in }
        let footer = FitMeasure.height(WelcomeFooter(session: session).padding(.vertical, Space.xl),
                                       width: WelcomeMetrics.window.width)
        return WelcomeMetrics.window.height - WelcomeMetrics.stageHeight - StrokeWidth.regular - Space.xl - footer
    }

    /// A step's lower half as `StepLayout` stacks it.
    static func lower(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.l) { content() }
    }

    /// The lower half of every step with `transform` applied to its words.
    static func lowers(_ transform: @escaping (String) -> String) -> [(String, AnyView)] {
        let services = WelcomePreview.services(updatesConfigured: true)
        let choices = WelcomeChoices()
        let hello = HelloStep.Copy.localized(in: englishBundle).map(transform)
        let displays = DisplaysStep.Copy.localized(in: englishBundle).map(transform)
        let defaults = DefaultsStep.Copy.localized(in: englishBundle).map(transform)
        let findIt = FindItStep.Copy.localized(in: englishBundle).map(transform)
        let done = DoneStep.Copy.localized(in: englishBundle).map(transform)
        return [
            ("hello", AnyView(lower { HelloLower(copy: hello, card: .preview(display: DisplayFixture.Keys.builtIn, gain: 1.29)) })),
            ("hello-none", AnyView(lower { HelloLower(copy: hello, card: .noneCapable) })),
            ("displays", AnyView(lower { StepHeader(title: displays.title, message: displays.message) })),
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

    /// The stage content of steps 3 and 4 with `transform` applied to its words.
    static func stages(_ transform: @escaping (String) -> String) -> [(String, AnyView)] {
        let services = WelcomePreview.services()
        let defaults = DefaultsStep.Copy.localized(in: englishBundle).map(transform)
        let findIt = FindItStep.Copy.localized(in: englishBundle).map(transform)
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
}
