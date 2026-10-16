// OverbrightDesign/Copy/Names/AutomationNames.swift — the user-facing names of the automation choices. DESIGN.md §5.9
// (footer chips and their menus, title case), §7.5 (Settings ▸ Automations, sentence case), §7.7 (cameras).
import Foundation
import OverbrightCore

public extension BatteryGuard {
    /// "Pause below a battery level" · "Pause on battery" · "Keep boosting" (Settings ▸ Automations ▸ On battery).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .belowThreshold: String(localized: "Pause below a battery level", bundle: b, locale: l,
                                     comment: "Settings ▸ Automations: On battery pop-up item (the default)")
        case .onlyOnAdapter: String(localized: "Pause on battery", bundle: b, locale: l,
                                    comment: "Settings ▸ Automations: On battery pop-up item")
        case .off: String(localized: "Keep boosting", bundle: b, locale: l,
                          comment: "Settings ▸ Automations: On battery pop-up item (extra brightness continues on battery)")
        }
    }

    /// "Pause Below a Level" · "Pause on Battery" · "Keep Boosting" (the Battery footer chip's menu, title case).
    nonisolated func menuTitle(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .belowThreshold: String(localized: "Pause Below a Level", bundle: b, locale: l,
                                     comment: "Panel ▸ Footer chip: Battery chip menu item (title case)")
        case .onlyOnAdapter: String(localized: "Pause on Battery", bundle: b, locale: l,
                                    comment: "Panel ▸ Footer chip: Battery chip menu item (title case)")
        case .off: String(localized: "Keep Boosting", bundle: b, locale: l,
                          comment: "Panel ▸ Footer chip: Battery chip menu item (title case)")
        }
    }
}

public extension PausedAppRule.Mode {
    /// "While in front" · "While playing (beta)" (Settings ▸ Automations, each app row).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .whileFrontmost: String(localized: "While in front", bundle: language.bundle, locale: language.locale,
                                     comment: "Settings ▸ Automations: an app pauses extra brightness while it is the front app (pop-up item)")
        case .whilePlaying: String(localized: "While playing (beta)", bundle: language.bundle, locale: language.locale,
                                   comment: "Settings ▸ Automations: an app pauses extra brightness while it plays video (pop-up item)")
        }
    }
}

public extension CameraFilter {
    /// "Any camera" · "Built-in and USB cameras only" (Settings ▸ Fill Light ▸ Cameras).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .anyCamera: String(localized: "Any camera", bundle: language.bundle, locale: language.locale,
                                comment: "Settings ▸ Fill Light: Cameras pop-up item (the default)")
        case .builtInAndUSB: String(localized: "Built-in and USB cameras only", bundle: language.bundle,
                                    locale: language.locale, comment: "Settings ▸ Fill Light: Cameras pop-up item")
        }
    }
}
