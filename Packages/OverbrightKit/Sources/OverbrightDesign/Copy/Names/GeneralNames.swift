// OverbrightDesign/Copy/Names/GeneralNames.swift — the user-facing names of the General and Shortcuts choices.
// DESIGN.md §7.3, §7.6. (The menu bar symbol's VoiceOver labels are AppShell's `StatusMenuText.symbolLabel(_:)`.)
import Foundation
import OverbrightCore

public extension LaunchBehavior {
    /// "Open Overbright and turn it on" · "Open Overbright, keep it off" · "Don't open Overbright"
    /// (Settings ▸ General ▸ When you log in).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .launchAndEnable: String(localized: "Open Overbright and turn it on", bundle: b, locale: l,
                                      comment: "Settings ▸ General: When you log in, radio button")
        case .launchOnly: String(localized: "Open Overbright, keep it off", bundle: b, locale: l,
                                 comment: "Settings ▸ General: When you log in, radio button (the default)")
        case .dontLaunch: String(localized: "Don’t open Overbright", bundle: b, locale: l,
                                 comment: "Settings ▸ General: When you log in, radio button")
        }
    }
}

public extension StatusClickAction {
    /// "Opens the panel" · "Turns Overbright on or off" (Settings ▸ General ▸ Clicking the icon).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .openPanel: String(localized: "Opens the panel", bundle: language.bundle, locale: language.locale,
                                comment: "Settings ▸ General: Clicking the icon, segment (the default)")
        case .toggle: String(localized: "Turns Overbright on or off", bundle: language.bundle, locale: language.locale,
                             comment: "Settings ▸ General: Clicking the icon, segment")
        }
    }
}

public extension StepSize {
    /// "Regular" · "Fine" (Settings ▸ Shortcuts ▸ Step size).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .regular: String(localized: "Regular", bundle: language.bundle, locale: language.locale,
                              comment: "Settings ▸ Shortcuts: Step size segment, about a fifth of the light per press")
        case .fine: String(localized: "Fine", bundle: language.bundle, locale: language.locale,
                           comment: "Settings ▸ Shortcuts: Step size segment, about 6 % of the light per press")
        }
    }
}
