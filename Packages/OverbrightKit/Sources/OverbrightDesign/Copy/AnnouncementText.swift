// OverbrightDesign/Copy/AnnouncementText.swift — the VoiceOver announcements of DESIGN.md §12.9. They go through
// Core's `Announcer`: the user's own changes are feedback (never rate-limited), automation stops are alerts (at most
// one per 10 s).
import Foundation

/// The announcements of DESIGN.md §12.9.
public nonisolated enum AnnouncementText {
    /// "Overbright on" / "Overbright off" (turned on or off from the icon).
    public static func overbright(isOn: Bool, in language: CopyLanguage = .app) -> String {
        isOn ? String(localized: "Overbright on", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: announced when Overbright turns on from the menu bar icon")
            : String(localized: "Overbright off", bundle: language.bundle, locale: language.locale,
                     comment: "VoiceOver: announced when Overbright turns off from the menu bar icon")
    }

    /// "Overbright turned off: the timer ended."
    public static func timerEnded(in language: CopyLanguage = .app) -> String {
        String(localized: "Overbright turned off: the timer ended.", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: announced when the auto-off timer turns Overbright off")
    }

    /// "Fill Light on" / "Fill Light off".
    public static func fillLight(isOn: Bool, in language: CopyLanguage = .app) -> String {
        isOn ? String(localized: "Fill Light on", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: announced when Fill Light turns on; “Fill Light” is the feature’s name")
            : String(localized: "Fill Light off", bundle: language.bundle, locale: language.locale,
                     comment: "VoiceOver: announced when Fill Light turns off")
    }
}
