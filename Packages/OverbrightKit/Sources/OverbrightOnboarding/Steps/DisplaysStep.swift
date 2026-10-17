// OverbrightOnboarding/Steps/DisplaysStep.swift — Welcome step 2 Displays (DESIGN.md §8, §12.1): the headline, then one
// row per display (glyph, name, verdict badge and sentence, the advisories Welcome shows, the fix button and the "Use
// extra brightness" switch for displays that can show it; the OLED notice when it turns on). The step has the split of
// every step (WP14 C-ONBOARD-1): a compact stage with one glyph per display, the headline at its boundary, then the
// rows down to the footer. The rows need the room, so the owner's two or three displays show at once
// (`DisplayRowList` scrolls visibly when more do not fit). Rows follow the display directory and the engine's verdicts,
// so they re-evaluate whenever the displays change (for example after HDR is turned on in System Settings) and
// cross-fade (`contentSwap`). The switches' choices wait in `WelcomeChoices` until Done; Skip drops them. Seeded by
// WP0b with its headline; built by WP12 (ARCHITECTURE.md §10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 2 Displays.
struct DisplaysStep: View {
    let session: WelcomeSession
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    /// The step's words.
    struct Copy {
        /// "Your displays".
        var title: String
        /// "Overbright checks what each display can do."
        var message: String
        /// The per-display switch.
        var useExtraBrightness: String
        /// The language of the rows' verdict words (Design's catalog; tests pick English).
        var verdictLanguage: CopyLanguage = .app
        /// Applied to the rows' verdict words: the fit tests' pseudo-long locale lengthens them too.
        var verdictWords: (String) -> String = { $0 }

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

        /// Every string passed through `transform` (the fit tests' pseudo-long locale), the verdicts' words included.
        func map(_ transform: @escaping (String) -> String) -> Copy {
            Copy(title: transform(title), message: transform(message), useExtraBrightness: transform(useExtraBrightness),
                 verdictLanguage: verdictLanguage, verdictWords: transform)
        }
    }

    var body: some View {
        let rows = WelcomeDisplayRow.rows(in: session.services, choices: session.choices, language: copy.verdictLanguage)
            .map { $0.map(copy.verdictWords) }
        StepLayout(stage: .compact) {
            StepStage(.compact) { StageGlyphs(symbols: rows.map { $0.isBuiltIn ? .laptopComputer : .display }) }
        } content: {
            StepHeader(title: copy.title, message: copy.message)
                .welcomeStepHeader()
            DisplayRowList(rows: rows, switchTitle: copy.useExtraBrightness,
                           actions: WelcomeDisplayActions(services: session.services, choices: session.choices))
        }
        .welcomeStepRoot()
    }
}

#Preview("2 Displays") {
    let services = WelcomePreview.services(.russianNames)
    return DisplaysStep(session: WelcomeSession(services: services, initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}

#Preview("2 Displays · three displays") {
    DisplaysStep(session: WelcomeSession(services: WelcomePreview.threeDisplays, initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}

#Preview("2 Displays · HDR off") {
    let services = WelcomePreview.services(.mpg322uxHDROff)
    return DisplaysStep(session: WelcomeSession(services: services, initialStep: .displays) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
