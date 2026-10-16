// OverbrightDesign/Copy/Names/CommonNames.swift — words that several names and values share, one key each.
// DESIGN.md §12, §16.
import Foundation

/// Words several names share.
public nonisolated enum CommonNames {
    /// "Automatic": the default choice of a method or a display type.
    public static func automatic(in language: CopyLanguage = .app) -> String {
        String(localized: "Automatic", bundle: language.bundle, locale: language.locale,
               comment: "Settings: a pop-up item that lets Overbright choose (method, trigger method)")
    }

    /// "Off": Overbright is off (the readout, the HUD value, VoiceOver values).
    public static func off(in language: CopyLanguage = .app) -> String {
        String(localized: "Off", bundle: language.bundle, locale: language.locale,
               comment: "Overbright is off: the readout, the HUD value and VoiceOver values")
    }

    /// "Dimmed": the dim half's state (VoiceOver values and actions, the menu bar icon's value).
    public static func dimmed(in language: CopyLanguage = .app) -> String {
        String(localized: "Dimmed", bundle: language.bundle, locale: language.locale,
               comment: "The state of a display dimmed below the macOS minimum (VoiceOver value and action, menu bar icon)")
    }

    /// "Preparing…": a display is being prepared (the readout, the chip, the HUD).
    public static func preparing(in language: CopyLanguage = .app) -> String {
        String(localized: "Preparing…", bundle: language.bundle, locale: language.locale,
               comment: "Panel: a display is being prepared for extra brightness (readout, status chip, HUD)")
    }
}
