// OverbrightDesign/Copy/RescueOutcome+Result.swift — what Reset Display Colors did, in words. DESIGN.md §12.4 (Reset
// display colors: the results shown inline under the button), §7.8 (Settings ▸ Advanced); ARCHITECTURE.md §7.4, D7,
// D27. The alert itself (title, message, buttons) belongs to the Advanced pane.
import Foundation
import OverbrightCore

public extension RescueOutcome {
    /// The inline result of Settings ▸ Advanced ▸ Reset Display Colors: "Display colors reset." · "Display colors
    /// were already normal." · "Display colors reset. Some displays were set back to their color profile directly." ·
    /// "Another brightness or color app is running. Quit it first." · "Some colors couldn't be reset. Change the color
    /// profile in Displays settings and back, or log out." · and, while this session is not the one on the displays,
    /// "Display colors can be reset only from the session shown on the displays."
    nonisolated func localizedResult(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .restored:
            String(localized: "Display colors reset.", bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors, every display is back to its color profile")
        case .alreadyNeutral:
            String(localized: "Display colors were already normal.", bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors when nothing needed resetting")
        case .repairedInvalidRestore:
            String(localized: "Display colors reset. Some displays were set back to their color profile directly.",
                   bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors when macOS’s own reset failed for some displays and Overbright wrote their profile")
        case .skippedBecauseTableWriterRuns:
            String(localized: "Another brightness or color app is running. Quit it first.", bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors while another app that changes display colors runs")
        case .residueRemains:
            String(localized: "Some colors couldn’t be reset. Change the color profile in Displays settings and back, or log out.",
                   bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors when a change made outside apps remains; “Displays” is macOS’s own name")
        case .skippedNotOnConsole:
            String(localized: "Display colors can be reset only from the session shown on the displays.", bundle: b, locale: l,
                   comment: "Settings ▸ Advanced: result of Reset Display Colors while another user’s session is on the displays (fast user switching)")
        }
    }
}
