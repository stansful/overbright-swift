// OverbrightOnboarding/Steps/DoneStep.swift — Welcome step 5 Done (DESIGN.md §8): the app icon on the stage (§14: Welcome
// shows the compiled icon), "You're set", a short summary of the choices of step 3 that Done applies (`DoneSummary`:
// the pause rules that are on and what happens at login, WP14 C-ONBOARD-1), and the "Check for updates on GitHub"
// switch (off; only when this build has a repository, `WelcomePlan.showsUpdateToggle`, D2). The footer offers Turn On
// Overbright (primary) only while a display would show extra brightness once it is on (`offersTurnOn`, step 2's
// switches included: Done writes them before it turns Overbright on), next to Done. Seeded by WP0b with its headline;
// built by WP12 (ARCHITECTURE.md §10.14).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 5 Done.
struct DoneStep: View {
    let session: WelcomeSession
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    /// The step's words.
    struct Copy {
        /// "You're set".
        var title: String
        /// "Check for updates on GitHub".
        var checkForUpdates: String
        /// The note under the switch.
        var updatesNote: String
        /// The summary's words: step 3's own switch labels and login card titles.
        var summary: DefaultsStep.Copy

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "You’re set", bundle: bundle, comment: "Welcome ▸ Done: headline"),
                 checkForUpdates: String(localized: "Check for updates on GitHub", bundle: bundle,
                                         comment: "Welcome ▸ Done: switch that turns on the daily update check (GitHub is the website’s name)"),
                 updatesNote: String(localized: "Overbright asks GitHub once a day. Nothing else is sent.", bundle: bundle,
                                     comment: "Welcome ▸ Done: note under the update check switch"),
                 summary: DefaultsStep.Copy.localized(in: bundle))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), checkForUpdates: transform(checkForUpdates), updatesNote: transform(updatesNote),
                 summary: summary.map(transform))
        }
    }

    var body: some View {
        let offersTurnOn = WelcomeDisplayRow.rows(in: session.services, choices: session.choices).offersTurnOn
        StepLayout {
            StepStage {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: StepMetrics.illustration, height: StepMetrics.illustration)
                    .accessibilityHidden(true)
            }
        } content: {
            StepHeader(title: copy.title)
                .welcomeStepHeader()
            DoneSummary(choices: session.choices, settings: session.services.settings, copy: copy.summary)
            if session.plan.showsUpdateToggle {
                UpdateSwitch(choices: session.choices, settings: session.services.settings, copy: copy)
            }
        }
        .welcomeStepRoot()
        .onAppear { session.offersTurnOn = offersTurnOn }
        .onChange(of: offersTurnOn) { _, offers in session.offersTurnOn = offers }
    }
}

/// Step 5's summary of the choices of step 3 that Done applies, in step 3's words and with its glyphs: the pause rules
/// that are on, then what happens at login. A rule that is off is left out.
struct DoneSummary: View {
    let choices: WelcomeChoices
    let settings: SettingsStore
    let copy: DefaultsStep.Copy

    /// One line of the summary.
    enum Line: Hashable {
        /// "Pause on battery below ‹level›".
        case battery(percent: Int)
        /// "Pause in Low Power Mode".
        case lowPower
        /// "Pause for full-screen video".
        case fullScreenVideo
        /// "When you log in ‹choice›".
        case login(LaunchBehavior)

        /// The glyph of the line: step 3's stage glyph of the rule, the power symbol for login.
        var symbol: OverbrightSymbol {
            switch self {
            case .battery: .battery25Percent
            case .lowPower: .boltFill
            case .fullScreenVideo: .playRectangleFill
            case .login: .power
            }
        }
    }

    /// The lines for the choices on screen (step 3's, else what is stored), in step 3's order.
    static func lines(choices: WelcomeChoices, settings: SettingsStore) -> [Line] {
        var lines: [Line] = []
        if choices.pausesOnBattery(in: settings) { lines.append(.battery(percent: choices.batteryThreshold(in: settings))) }
        if choices.pauseInLowPowerMode(in: settings) { lines.append(.lowPower) }
        if choices.pauseForFullScreenVideo(in: settings) { lines.append(.fullScreenVideo) }
        lines.append(.login(choices.launchBehavior(in: settings)))
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(Self.lines(choices: choices, settings: settings), id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    Image(symbol: line.symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: StepMetrics.summaryGlyphColumn)
                        .accessibilityHidden(true)
                    words(line)
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stepCard()
    }

    /// The words of `line`, wrapping when a translation is long.
    @ViewBuilder private func words(_ line: Line) -> some View {
        switch line {
        case let .battery(percent):
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text(verbatim: copy.battery).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: GuardSwitches.percentText(percent)).fixedSize()
            }
        case .lowPower:
            Text(verbatim: copy.lowPower).fixedSize(horizontal: false, vertical: true)
        case .fullScreenVideo:
            Text(verbatim: copy.fullScreenVideo).fixedSize(horizontal: false, vertical: true)
        case let .login(behavior):
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(verbatim: copy.loginGroup).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: copy.title(of: behavior)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Step 5's update switch and its note.
struct UpdateSwitch: View {
    let choices: WelcomeChoices
    let settings: SettingsStore
    let copy: DoneStep.Copy

    var body: some View {
        let isOn = choices.checksForUpdates(in: settings)
        VStack(alignment: .leading, spacing: Space.xs) {
            Toggle(isOn: Binding(get: { isOn }, set: { choices.checksForUpdates = $0 })) {
                Text(verbatim: copy.checkForUpdates)
            }
            .toggleStyle(.accentSwitch)
            .controlSize(.small)
            Text(verbatim: copy.updatesNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("5 Done") {
    let services = WelcomePreview.services(updatesConfigured: true)
    return DoneStep(session: WelcomeSession(services: services, initialStep: .done) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
