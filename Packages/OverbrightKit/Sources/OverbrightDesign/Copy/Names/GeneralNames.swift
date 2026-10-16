// OverbrightDesign/Copy/Names/GeneralNames.swift — the user-facing names of the General and Shortcuts choices and
// of the menu bar symbol's states. DESIGN.md §4.1, §7.3, §7.6, §8 (Welcome step 3), §12.7.
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

    /// "Open and turn on" · "Open, keep off" · "Don't open at login" (the Welcome window's option cards).
    nonisolated func shortName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .launchAndEnable: String(localized: "Open and turn on", bundle: b, locale: l,
                                      comment: "Welcome ▸ Defaults: login option card")
        case .launchOnly: String(localized: "Open, keep off", bundle: b, locale: l,
                                 comment: "Welcome ▸ Defaults: login option card (the default, marked Recommended)")
        case .dontLaunch: String(localized: "Don’t open at login", bundle: b, locale: l,
                                 comment: "Welcome ▸ Defaults: login option card")
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

public extension StatusSymbolState {
    /// "Overbright, off": the menu bar symbol's accessibility description (DESIGN.md §4.1).
    nonisolated func accessibilityLabel(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .off: String(localized: "Overbright, off", bundle: b, locale: l,
                          comment: "VoiceOver: the menu bar icon while Overbright is off")
        case .on: String(localized: "Overbright, on", bundle: b, locale: l,
                         comment: "VoiceOver: the menu bar icon while Overbright is on")
        case .preparing: String(localized: "Overbright, preparing", bundle: b, locale: l,
                                comment: "VoiceOver: the menu bar icon while a display is being prepared")
        case .dimming: String(localized: "Overbright, dimmed", bundle: b, locale: l,
                              comment: "VoiceOver: the menu bar icon while every changed display is dimmed")
        case .paused: String(localized: "Overbright, paused", bundle: b, locale: l,
                             comment: "VoiceOver: the menu bar icon while Overbright is paused")
        case .attention: String(localized: "Overbright, needs attention", bundle: b, locale: l,
                                comment: "VoiceOver: the menu bar icon while something needs the user’s attention")
        }
    }

    /// "On" · "Off" · "Preparing" · "Dimmed" · "Paused" · "Needs attention": the status item's value (DESIGN.md §12.7).
    nonisolated func accessibilityValue(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .off: CommonNames.off(in: language)
        case .on: String(localized: "On", bundle: b, locale: l,
                         comment: "VoiceOver: the value of the menu bar icon and the master switch while Overbright is on")
        case .preparing: String(localized: "Preparing", bundle: b, locale: l,
                                comment: "VoiceOver: the value of the menu bar icon while a display is being prepared")
        case .dimming: CommonNames.dimmed(in: language)
        case .paused: String(localized: "Paused", bundle: b, locale: l,
                             comment: "VoiceOver: the value of the menu bar icon while Overbright is paused")
        case .attention: String(localized: "Needs attention", bundle: b, locale: l,
                                comment: "VoiceOver: the value of the menu bar icon while something needs attention")
        }
    }
}
