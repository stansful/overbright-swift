// OverbrightDesign/Copy/ConfirmationText.swift — the confirmations of DESIGN.md §12.9: Keep this level? (the HUD's
// prompt after a level below 10 % of Standard light) and Reset ‹Pane› (Settings).
import Foundation

/// The confirmations of DESIGN.md §12.9.
public nonisolated enum ConfirmationText {
    /// "Keep this level?"
    public static func keepLevelTitle(in language: CopyLanguage = .app) -> String {
        String(localized: "Keep this level?", bundle: language.bundle, locale: language.locale,
               comment: "HUD: title of the prompt after a very dark level was set")
    }

    /// "Going back in 10 sec" (counting down).
    public static func goingBack(seconds: Int, in language: CopyLanguage = .app) -> String {
        let time = CopyFormat.seconds(seconds, spelledOut: false, in: language)
        return String(localized: "Going back in \(time)", bundle: language.bundle, locale: language.locale,
                      comment: "HUD: the Keep this level? countdown; the argument is a duration such as 10 sec")
    }

    /// "Keep this level? Going back in 10 seconds." (VoiceOver).
    public static func keepLevelAnnouncement(seconds: Int, in language: CopyLanguage = .app) -> String {
        let time = CopyFormat.seconds(seconds, spelledOut: true, in: language)
        return String(localized: "Keep this level? Going back in \(time).", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: announced with the Keep this level? prompt; the argument is a duration such as 10 seconds")
    }

    /// "Go Back" (Esc).
    public static func goBack(in language: CopyLanguage = .app) -> String {
        String(localized: "Go Back", bundle: language.bundle, locale: language.locale,
               comment: "HUD: Keep this level? button that returns to the previous level (title case)")
    }

    /// "Keep" (Return).
    public static func keep(in language: CopyLanguage = .app) -> String {
        String(localized: "Keep", bundle: language.bundle, locale: language.locale,
               comment: "HUD: Keep this level? button that keeps the dark level (title case)")
    }

    /// "Reset Displays settings?" and its message; `includesCalibration` for the Displays pane.
    public static func resetPane(_ pane: String, includesCalibration: Bool,
                                 in language: CopyLanguage = .app) -> (title: String, message: String) {
        let (b, l) = (language.bundle, language.locale)
        let name = pane.overbrightIsolated
        let title = String(localized: "Reset \(name) settings?", bundle: b, locale: l,
                           comment: "Settings: title of the alert of a pane’s Reset button; the argument is the pane’s name")
        let message = includesCalibration
            ? String(localized: "Every setting in \(name) returns to its default, including display calibration.", bundle: b,
                     locale: l, comment: "Settings: message of the Displays pane’s Reset alert; the argument is the pane’s name")
            : String(localized: "Every setting in \(name) returns to its default.", bundle: b, locale: l,
                     comment: "Settings: message of a pane’s Reset alert; the argument is the pane’s name")
        return (title, message)
    }
}
