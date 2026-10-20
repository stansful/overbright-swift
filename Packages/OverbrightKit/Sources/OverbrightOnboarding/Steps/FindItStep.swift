// OverbrightOnboarding/Steps/FindItStep.swift — Welcome step 4 Find it (DESIGN.md §8): on the stage, the menu bar with
// Overbright's symbol ("Click for the panel, right-click for the menu") and the key caps of the live Turn on or off,
// Back to Standard and Dim Below Minimum On or Off shortcuts in the current keyboard layout (a row without a registered
// shortcut is left out; key caps are never literal, §16; while Back to Standard has none, as on a first run, one line
// "You can set keyboard shortcuts in Settings ▸ Shortcuts." opens Settings ▸ Shortcuts there); under the copy, "Shortcuts app and Control Center" with the
// Run Shortcut recipe (§7.6) and how to see Settings again. Seeded by WP0b with its headline; built by WP12
// (ARCHITECTURE.md §10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI

/// Welcome step 4 Find it.
struct FindItStep: View {
    let session: WelcomeSession
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    /// The step's words.
    struct Copy {
        /// "Where to find Overbright".
        var title: String
        /// "Overbright lives in the menu bar."
        var message: String
        /// The caption under the menu bar.
        var menuBar: String
        /// "Turn on or off".
        var toggle: String
        /// "Back to Standard".
        var standard: String
        /// "Dim Below Minimum On or Off".
        var dimToggle: String
        /// "You can set keyboard shortcuts in Settings ▸ Shortcuts." (while Back to Standard has no shortcut).
        var setShortcuts: String
        /// "Shortcuts app and Control Center".
        var shortcutsHeading: String
        /// The Run Shortcut recipe.
        var recipe: String
        /// How to see Settings again.
        var finder: String

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "Where to find Overbright", bundle: bundle, comment: "Welcome ▸ Find it: headline"),
                 message: String(localized: "Overbright lives in the menu bar.", bundle: bundle,
                                 comment: "Welcome ▸ Find it: body under the headline"),
                 menuBar: String(localized: "Click for the panel, right-click for the menu", bundle: bundle,
                                 comment: "Welcome ▸ Find it: caption under the picture of Overbright’s menu bar symbol"),
                 toggle: String(localized: "Turn on or off", bundle: bundle,
                                comment: "Welcome ▸ Find it: next to the key caps of the shortcut that turns Overbright on or off"),
                 standard: String(localized: "Back to Standard", bundle: bundle,
                                  comment: "Welcome ▸ Find it: next to the key caps of the Back to Standard shortcut"),
                 dimToggle: String(localized: "Dim Below Minimum On or Off", bundle: bundle,
                                   comment: "Welcome ▸ Find it: next to the key caps of the shortcut that dims every display below the minimum or brings them back"),
                 setShortcuts: String(localized: "You can set keyboard shortcuts in Settings ▸ Shortcuts.", bundle: bundle,
                                      comment: "Welcome ▸ Find it: link shown while Back to Standard has no keyboard shortcut (none is set at first); opens Overbright’s Settings window at its Shortcuts pane"),
                 shortcutsHeading: String(localized: "Shortcuts app and Control Center", bundle: bundle,
                                          comment: "Welcome ▸ Find it: heading of the Run Shortcut recipe"),
                 recipe: String(localized: "To put Overbright in Control Center or the menu bar, make a shortcut with Turn Overbright On or Off, then add Control Center’s Run Shortcut control.",
                                bundle: bundle,
                                comment: "Welcome ▸ Find it: the Run Shortcut recipe (Turn Overbright On or Off is the Shortcuts action’s title; Run Shortcut is Control Center’s control)"),
                 finder: String(localized: "Open Overbright again from Finder or Spotlight to see Settings.", bundle: bundle,
                                comment: "Welcome ▸ Find it: how to reach Settings when the menu bar icon is hidden"))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), message: transform(message), menuBar: transform(menuBar),
                 toggle: transform(toggle), standard: transform(standard), dimToggle: transform(dimToggle),
                 setShortcuts: transform(setShortcuts), shortcutsHeading: transform(shortcutsHeading),
                 recipe: transform(recipe), finder: transform(finder))
        }

        /// What a shortcut row says the shortcut does.
        func title(of id: ShortcutID) -> String {
            switch id {
            case .standard: standard
            case .dimToggle: dimToggle
            default: toggle
            }
        }
    }

    var body: some View {
        StepLayout {
            StepStage {
                FindItStage(shortcuts: FindItShortcut.rows(session.services.shortcuts), copy: copy,
                            openShortcutSettings: openShortcutSettings)
            }
        } content: {
            StepHeader(title: copy.title, message: copy.message)
                .welcomeStepHeader()
            FindItLower(copy: copy)
        }
        .welcomeStepRoot()
    }

    /// Opens Settings ▸ Shortcuts at Back to Standard ("You can set keyboard shortcuts in Settings ▸ Shortcuts.").
    func openShortcutSettings() {
        session.services.app?.openSettings(SettingsLinks.backToStandardShortcut)
    }
}

/// Step 4's copy under the header: the Run Shortcut recipe and how to see Settings again.
struct FindItLower: View {
    let copy: FindItStep.Copy

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(verbatim: copy.shortcutsHeading)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: copy.recipe)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Text(verbatim: copy.finder)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("4 Find it") {
    FindItStep(session: WelcomeSession(services: WelcomePreview.services(), initialStep: .findIt) { _ in })
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
