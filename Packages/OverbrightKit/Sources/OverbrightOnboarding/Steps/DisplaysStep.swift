// OverbrightOnboarding/Steps/DisplaysStep.swift — Welcome step 2 Displays (DESIGN.md §8, §12.1): one row per display on
// the stage (glyph, name, verdict badge and sentence, advisories, the fix button and the "Use extra brightness" switch
// for displays that can show it; the OLED notice when it turns on). Rows follow the display directory and the engine's
// verdicts, so they re-evaluate whenever the displays change (for example after HDR is turned on in System Settings)
// and cross-fade (`contentSwap`). Seeded by WP0b with its headline; built by WP12 (ARCHITECTURE.md §10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 2 Displays.
struct DisplaysStep: View {
    let session: WelcomeSession
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    @Environment(\.overbright) private var theme

    /// The step's words.
    struct Copy {
        /// "Your displays".
        var title: String
        /// "Overbright checks what each display can do."
        var message: String
        /// The per-display switch.
        var useExtraBrightness: String

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "Your displays", bundle: bundle, comment: "Welcome ▸ Displays: headline"),
                 message: String(localized: "Overbright checks what each display can do.", bundle: bundle,
                                 comment: "Welcome ▸ Displays: body under the headline"),
                 useExtraBrightness: String(localized: "Use extra brightness", bundle: bundle,
                                            comment: "Welcome ▸ Displays: switch that turns extra brightness on or off for this display"))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), message: transform(message), useExtraBrightness: transform(useExtraBrightness))
        }
    }

    var body: some View {
        let rows = WelcomeDisplayRow.rows(in: session.services)
        let actions = WelcomeDisplayActions(services: session.services)
        StepLayout {
            StepStage {
                ScrollView {
                    VStack(spacing: Space.s) {
                        ForEach(rows) { row in
                            DisplayRowView(row: row, switchTitle: copy.useExtraBrightness, actions: actions)
                                .transition(.opacity)
                        }
                    }
                    .animation(theme.animation(.contentSwap), value: rows)
                }
                .scrollIndicators(.automatic)
            }
        } content: {
            StepHeader(title: copy.title, message: copy.message)
                .welcomeStepHeader()
        }
        .welcomeStepRoot()
    }
}

#Preview("2 Displays") {
    DisplaysStep(session: WelcomeSession(services: WelcomePreview.services(.russianNames), initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}

#Preview("2 Displays · HDR off") {
    DisplaysStep(session: WelcomeSession(services: WelcomePreview.services(.mpg322uxHDROff), initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
