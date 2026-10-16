// OverbrightDesign/Copy/Names/ShortcutNames.swift — the user-facing names of the global shortcuts and the step
// directions, and the menu commands they stand for. DESIGN.md §4.3 (the menu), §4.4 (the Dock menu), §5.3 (the panel's
// overflow menu), §7.6 (Settings ▸ Shortcuts), §8 (Welcome step 4), §16 (vocabulary: Brighter · Less Bright, Back to
// Standard, Dim All Displays). Key caps are never part of a name: they come from `ShortcutCenter.displayString(_:)`.
import Foundation
import OverbrightCore

public extension ShortcutID {
    /// "Turn Overbright on or off" · "Brighter" · "Less Bright" · "Max" · "Dim Below Minimum On or Off" · "Back to
    /// Standard" · "Fill Light": the row names of Settings ▸ Shortcuts, also used by the Welcome window's key-cap rows
    /// and the recorder's "Already used for Brighter." Nil for an identifier this build does not know.
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String? {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .toggle: String(localized: "Turn Overbright on or off", bundle: b, locale: l,
                             comment: "Settings ▸ Shortcuts: row of the shortcut that turns Overbright on or off")
        case .brighter: ShortcutWords.brighter(in: language)
        case .lessBright: ShortcutWords.lessBright(in: language)
        case .max: String(localized: "shortcut.max", defaultValue: "Max", bundle: b, locale: l,
                          comment: "Settings ▸ Shortcuts: row of the shortcut that sets every display to its top preset, Max")
        case .dimToggle: String(localized: "Dim Below Minimum On or Off", bundle: b, locale: l,
                                comment: "Settings ▸ Shortcuts: row of the shortcut that dims every display below the macOS minimum, or brings them back (title case)")
        case .standard: ShortcutWords.backToStandard(in: language)
        case .fillLight: ShortcutWords.fillLight(in: language)
        default: nil
        }
    }

    /// The command a shortcut stands for in the menu, the Dock menu and the panel's ⋯ menu (title case): "Turn Off
    /// Overbright" while `isActive` (Overbright is on), else "Turn On Overbright"; "Stop Dimming" while `isActive`
    /// (the displays are dimmed), else "Dim All Displays"; "Back to Standard", "Brighter", "Less Bright", "Max",
    /// "Fill Light". Nil for an identifier this build does not know.
    nonisolated func menuTitle(isActive: Bool = false, in language: CopyLanguage = .app) -> String? {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .toggle where isActive: String(localized: "Turn Off Overbright", bundle: b, locale: l,
                                            comment: "Menu: turns Overbright off; also in the Dock menu (title case)")
        case .toggle: String(localized: "Turn On Overbright", bundle: b, locale: l,
                             comment: "Menu: turns Overbright on; also in the Dock menu (title case)")
        case .dimToggle where isActive: String(localized: "Stop Dimming", bundle: b, locale: l,
                                               comment: "Menu: brings dimmed displays back to Standard; also in the Dock and panel menus (title case)")
        case .dimToggle: String(localized: "Dim All Displays", bundle: b, locale: l,
                                comment: "Menu: dims every display to the last dim level; also in the Dock and panel menus (title case)")
        case .max: LevelPreset.max.menuTitle(in: language)
        default: localizedName(in: language)
        }
    }
}

public extension StepDirection {
    /// "Brighter" · "Less Bright": one step up or down (the shortcuts' names; DESIGN.md §16 never says "Dimmer").
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        switch self {
        case .brighter: ShortcutWords.brighter(in: language)
        case .lessBright: ShortcutWords.lessBright(in: language)
        }
    }
}

/// The words that both a shortcut row and a menu command use, one key each.
private nonisolated enum ShortcutWords {
    static func brighter(in language: CopyLanguage) -> String {
        String(localized: "Brighter", bundle: language.bundle, locale: language.locale,
               comment: "Settings ▸ Shortcuts: the one-step-up shortcut and command (also in menus); never “Dimmer” for its opposite")
    }

    static func lessBright(in language: CopyLanguage) -> String {
        String(localized: "Less Bright", bundle: language.bundle, locale: language.locale,
               comment: "Settings ▸ Shortcuts: the one-step-down shortcut and command (also in menus), title case as a command name")
    }

    static func backToStandard(in language: CopyLanguage) -> String {
        String(localized: "Back to Standard", bundle: language.bundle, locale: language.locale,
               comment: "Settings ▸ Shortcuts: the instant-off shortcut and command (also in the Dock menu and Welcome); “Standard” is the level macOS itself shows")
    }

    static func fillLight(in language: CopyLanguage) -> String {
        String(localized: "Fill Light", bundle: language.bundle, locale: language.locale,
               comment: "Settings ▸ Shortcuts: the Fill Light shortcut and menu item; “Fill Light” is the feature’s name")
    }
}
