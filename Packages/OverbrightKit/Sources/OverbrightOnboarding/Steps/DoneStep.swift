// OverbrightOnboarding/Steps/DoneStep.swift — Welcome step 5 Done (DESIGN.md §8): the app icon on the stage (§14: Welcome
// shows the compiled icon), "You're set", and the "Check for updates on GitHub" switch (off; only when this build has a
// repository, `WelcomePlan.showsUpdateToggle`, D2). The footer offers Turn On Overbright (primary) only while a display
// would show extra brightness once it is on (`offersTurnOn`), next to Done. Seeded by WP0b with its headline; built by
// WP12 (ARCHITECTURE.md §10.14).
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

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "You’re set", bundle: bundle, comment: "Welcome ▸ Done: headline"),
                 checkForUpdates: String(localized: "Check for updates on GitHub", bundle: bundle,
                                         comment: "Welcome ▸ Done: switch that turns on the daily update check (GitHub is the website’s name)"),
                 updatesNote: String(localized: "Overbright asks GitHub once a day. Nothing else is sent.", bundle: bundle,
                                     comment: "Welcome ▸ Done: note under the update check switch"))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), checkForUpdates: transform(checkForUpdates), updatesNote: transform(updatesNote))
        }
    }

    var body: some View {
        let offersTurnOn = WelcomeDisplayRow.rows(in: session.services).offersTurnOn
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
            if session.plan.showsUpdateToggle {
                UpdateSwitch(choices: session.choices, settings: session.services.settings, copy: copy)
            }
        }
        .welcomeStepRoot()
        .onAppear { session.offersTurnOn = offersTurnOn }
        .onChange(of: offersTurnOn) { _, offers in session.offersTurnOn = offers }
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
            .toggleStyle(.switch)
            .controlSize(.small)
            Text(verbatim: copy.updatesNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("5 Done") {
    DoneStep(session: WelcomeSession(services: WelcomePreview.services(updatesConfigured: true), initialStep: .done) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
