// OverbrightSettingsUI/Panes/DisplaysRows.swift — the rows of Settings ▸ Displays (DESIGN.md §7.4), shared by the pane
// and the search index. The per-display rows exist once per connected display: their ids carry the display key
// ("displays#<KEY>" opens the display's section, "displays#<KEY>.limit" its Limit row, the links PanelUI's
// `SettingsLinks` builds), and their keywords carry the display's name, so "MPG limit" finds that display's Limit.
import Foundation
import OverbrightCore
import OverbrightDesign

/// The rows of Settings ▸ Displays.
enum DisplaysRows {
    static var linkLevels: SettingsRowInfo {
        SettingsRowInfo(.displays, "linkLevels",
                        title: String(localized: "Same level on all displays", bundle: .module, comment: "Settings ▸ Displays: switch"),
                        keywords: [String(localized: "link", bundle: .module, comment: "Settings search: keyword for Same level on all displays")])
    }

    static var nearFullBrightness: SettingsRowInfo {
        SettingsRowInfo(.displays, "nearFullBrightness",
                        title: String(localized: "Add extra brightness only near full brightness", bundle: .module,
                                      comment: "Settings ▸ Displays: switch (extra brightness fades out as the display brightness goes down)"),
                        keywords: [PaneWords.brightness,
                                   String(localized: "brightness keys", bundle: .module,
                                          comment: "Settings search: keyword for Add extra brightness only near full brightness")])
    }

    /// The section of one display (its header: the name and the verdict badge).
    static func section(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, display.rawValue, title: name, keywords: [PaneWords.hdr, PaneWords.xdr])
    }

    static func extraBrightness(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).extraBrightness",
                        title: String(localized: "Use extra brightness on this display", bundle: .module,
                                      comment: "Settings ▸ Displays: per-display switch of extra brightness"),
                        keywords: [name, PaneWords.hdr, PaneWords.xdr, PaneWords.brighter])
    }

    static func level(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).level",
                        title: String(localized: "Level", bundle: .module,
                                      comment: "Settings ▸ Displays: the display’s level slider (dim below minimum, Standard, extra brightness)"),
                        keywords: [name, PaneWords.brighter, PaneWords.dim, PaneWords.nits])
    }

    static func limit(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).limit",
                        title: String(localized: "Limit", bundle: .module,
                                      comment: "Settings ▸ Displays: the ceiling of extra brightness, Safe or Peak (segmented)"),
                        keywords: [name, CapMode.safe.localizedName(), CapMode.peak.localizedName()])
    }

    static func method(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).method",
                        title: String(localized: "Method", bundle: .module,
                                      comment: "Settings ▸ Displays: how Overbright brightens the display, Automatic, Color table or Compatibility mode (pop-up)"),
                        keywords: [name] + methodKeywords)
    }

    /// The names the Method row is found by: its methods, without Compatibility mode while it is unavailable.
    private static var methodKeywords: [String] {
        (MechanismPreference.overlayIsAvailable ? [Mechanism.overlay.localizedName()] : [])
            + [Mechanism.table.localizedName()]
    }

    static func calibration(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).calibration",
                        title: String(localized: "Calibration", bundle: .module,
                                      comment: "Settings ▸ Displays: the display’s calibration result and the Calibrate… button"),
                        keywords: [name, PaneWords.nits,
                                   String(localized: "colorimeter", bundle: .module, comment: "Settings search: keyword for Calibration")])
    }

    static func displayType(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).type",
                        title: String(localized: "Display type", bundle: .module,
                                      comment: "Settings ▸ Displays: whether an external display is OLED (pop-up)"),
                        keywords: [name, PaneWords.oled])
    }

    static func autoBrightness(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "\(display.rawValue).autoBrightness",
                        title: String(localized: "Automatically adjust brightness", bundle: .module,
                                      comment: "Settings ▸ Displays: search title of the advisory row; macOS’s own name of the setting in Displays settings"),
                        keywords: [name, PaneWords.brightness])
    }

    /// A display that is not connected now (listed with its last name and Forget).
    static func remembered(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.displays, "remembered.\(display.rawValue)", title: name,
                        keywords: [String(localized: "forget", bundle: .module, comment: "Settings search: keyword for a display that is not connected")])
    }

    /// "Unnamed display": the name of a remembered display that never had one stored.
    static var unnamedDisplay: String {
        String(localized: "Unnamed display", bundle: .module,
               comment: "Settings ▸ Displays: name of a remembered display whose name was never seen")
    }
}
