// OverbrightPanelUI/Card/MenuTitles.swift — title-case menu rows of the panel (the card's context menu, the "⋯" menu)
// and the quick levels the status menu reuses. DESIGN.md §4.3, §5.3, §5.4 (exact English; menus are title case,
// AppKit chrome); the preset names in title case belong to menus (the readout's sentence-case names are Design's).
import Foundation
import OverbrightCore

/// Title-case menu titles.
public enum MenuTitles {
    /// A level row: "Standard", "Indoor", "Bright Room", "Sunlight", "Max".
    public static func level(_ preset: LevelPreset) -> String {
        switch preset {
        case .standard: String(localized: "Standard", bundle: .module, comment: "Menu: the level row that returns a display to Standard")
        case .indoor: String(localized: "Indoor", bundle: .module, comment: "Menu: the Indoor preset (title case)")
        case .brightRoom: String(localized: "Bright Room", bundle: .module, comment: "Menu: the Bright room preset (title case)")
        case .sunlight: String(localized: "Sunlight", bundle: .module, comment: "Menu: the Sunlight preset (title case)")
        case .max: String(localized: "Max", bundle: .module, comment: "Menu: the Max preset (title case)")
        }
    }

    /// The disabled row of a display that cannot boost.
    public static var noExtraBrightness: String {
        String(localized: "No Extra Brightness on This Display", bundle: .module,
               comment: "Menu: disabled row in place of the presets on a display that cannot show extra brightness")
    }

    /// Turns extra brightness off for the display.
    public static var dontUse: String {
        String(localized: "Don’t Use on This Display", bundle: .module,
               comment: "Menu: turns extra brightness off for this display and returns it to Standard")
    }

    /// Turns extra brightness on for the display.
    public static var useExtraBrightness: String {
        String(localized: "Use Extra Brightness on This Display", bundle: .module,
               comment: "Menu: turns extra brightness on for this display")
    }

    /// Opens the calibration.
    public static var calibrate: String {
        String(localized: "Calibrate…", bundle: .module, comment: "Menu: card context menu row that opens the calibration")
    }

    /// Opens Settings ▸ Displays at the display.
    public static var settingsForDisplay: String {
        String(localized: "Settings for This Display…", bundle: .module,
               comment: "Menu: card context menu row that opens Overbright’s Settings at this display")
    }

    /// Clears a trip.
    public static var tryAgain: String {
        String(localized: "Try Again", bundle: .module, comment: "Menu: card context menu row that clears a stop")
    }

    /// The "⋯" menu and the status menu: dims every display.
    public static var dimAll: String {
        String(localized: "Dim All Displays", bundle: .module, comment: "Menu: dims every display to the last dim level")
    }

    /// The same row while every display is dimmed.
    public static var stopDimming: String {
        String(localized: "Stop Dimming", bundle: .module, comment: "Menu: returns every dimmed display to its level")
    }

    /// Fill Light (checked while on).
    public static var fillLight: String {
        String(localized: "Fill Light", bundle: .module, comment: "Menu: turns Fill Light on or off")
    }

    /// Opens Settings.
    public static var settings: String {
        String(localized: "Settings…", bundle: .module, comment: "Menu: the panel’s ⋯ menu row that opens Settings")
    }

    /// Opens the self-test.
    public static var runSelfTest: String {
        String(localized: "Run Self-Test…", bundle: .module, comment: "Menu: the panel’s ⋯ menu row that opens the self-test")
    }

    /// Opens Help.
    public static var help: String {
        String(localized: "Help", bundle: .module, comment: "Menu: the panel’s ⋯ menu row that opens the Help window")
    }

    /// Quits.
    public static var quit: String {
        String(localized: "Quit Overbright", bundle: .module, comment: "Menu: the panel’s ⋯ menu row that quits Overbright")
    }
}
