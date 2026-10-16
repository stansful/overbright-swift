// OverbrightOnboarding/Steps/DefaultsStep.swift — Welcome step 3 Defaults (DESIGN.md §8): the guard switches on the stage
// (Pause on battery below ‹level›, Pause in Low Power Mode, Pause for full-screen video, and the note that it also
// backs off when the Mac gets warm), then the three login option cards under the copy (Open and turn on · Open, keep
// off, "Recommended" · Don't open at login). The choices wait in `WelcomeChoices` until Done; Skip drops them.
// Seeded by WP0b with its headline; built by WP12 (ARCHITECTURE.md §10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 3 Defaults.
struct DefaultsStep: View {
    let session: WelcomeSession
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    /// The step's words.
    struct Copy {
        /// "How Overbright behaves".
        var title: String
        /// The sentence under the headline.
        var message: String
        /// "Pause on battery below" (the level pop-up follows).
        var battery: String
        /// VoiceOver's name of the level pop-up.
        var batteryLevel: String
        /// "Pause in Low Power Mode".
        var lowPower: String
        /// "Pause for full-screen video".
        var fullScreenVideo: String
        /// The note under the switches.
        var warmNote: String
        /// VoiceOver's name of the login cards.
        var loginGroup: String
        /// The login cards, in order.
        var openAndTurnOn: String
        /// "Open, keep off".
        var openKeepOff: String
        /// "Don't open at login".
        var dontOpen: String
        /// The badge of the recommended card.
        var recommended: String

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "How Overbright behaves", bundle: bundle, comment: "Welcome ▸ Defaults: headline"),
                 message: String(localized: "Extra light uses more power, so Overbright steps back on its own. Choose how it starts.",
                                 bundle: bundle, comment: "Welcome ▸ Defaults: body under the headline"),
                 battery: String(localized: "Pause on battery below", bundle: bundle,
                                 comment: "Welcome ▸ Defaults: switch label, followed by the battery level pop-up (“20 %”)"),
                 batteryLevel: String(localized: "Battery level", bundle: bundle,
                                      comment: "VoiceOver: Welcome ▸ Defaults, the pop-up with the battery level below which extra brightness pauses"),
                 lowPower: String(localized: "Pause in Low Power Mode", bundle: bundle,
                                  comment: "Welcome ▸ Defaults: switch label (Low Power Mode is macOS’s name)"),
                 fullScreenVideo: String(localized: "Pause for full-screen video", bundle: bundle,
                                         comment: "Welcome ▸ Defaults: switch label (pauses while an app plays video full screen)"),
                 warmNote: String(localized: "It also backs off when your Mac gets warm.", bundle: bundle,
                                  comment: "Welcome ▸ Defaults: note under the switches (extra brightness is limited by heat)"),
                 loginGroup: String(localized: "When you log in", bundle: bundle,
                                    comment: "VoiceOver: Welcome ▸ Defaults, the group of the three login option cards"),
                 openAndTurnOn: String(localized: "Open and turn on", bundle: bundle,
                                       comment: "Welcome ▸ Defaults: login option card (open Overbright at login and turn it on)"),
                 openKeepOff: String(localized: "Open, keep off", bundle: bundle,
                                     comment: "Welcome ▸ Defaults: login option card (open Overbright at login, keep it off; the default)"),
                 dontOpen: String(localized: "Don’t open at login", bundle: bundle,
                                  comment: "Welcome ▸ Defaults: login option card (Overbright is not a login item)"),
                 recommended: String(localized: "Recommended", bundle: bundle,
                                     comment: "Welcome ▸ Defaults: badge on the recommended login option card"))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), message: transform(message), battery: transform(battery),
                 batteryLevel: transform(batteryLevel), lowPower: transform(lowPower),
                 fullScreenVideo: transform(fullScreenVideo), warmNote: transform(warmNote),
                 loginGroup: transform(loginGroup), openAndTurnOn: transform(openAndTurnOn),
                 openKeepOff: transform(openKeepOff), dontOpen: transform(dontOpen), recommended: transform(recommended))
        }

        /// The title of a login option card.
        func title(of behavior: LaunchBehavior) -> String {
            switch behavior {
            case .launchAndEnable: openAndTurnOn
            case .launchOnly: openKeepOff
            case .dontLaunch: dontOpen
            }
        }
    }

    var body: some View {
        StepLayout {
            StepStage {
                GuardSwitches(choices: session.choices, settings: session.services.settings, copy: copy)
            }
        } content: {
            StepHeader(title: copy.title, message: copy.message)
                .welcomeStepHeader()
            LoginOptions(choices: session.choices, settings: session.services.settings, copy: copy)
        }
        .welcomeStepRoot()
    }
}

#Preview("3 Defaults") {
    DefaultsStep(session: WelcomeSession(services: WelcomePreview.services(), initialStep: .defaults) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
