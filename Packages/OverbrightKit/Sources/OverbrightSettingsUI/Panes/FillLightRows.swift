// OverbrightSettingsUI/Panes/FillLightRows.swift — the rows of Settings ▸ Fill Light (DESIGN.md §7.7), shared by the
// pane and the search index.
import Foundation
import OverbrightCore

/// The rows of Settings ▸ Fill Light.
enum FillLightRows {
    /// The switch: titled with the feature's name, the pane's own name.
    static var fillLight: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "fillLight", title: SettingsPane.pane(.fillLight).title,
                        keywords: [PaneWords.camera,
                                   String(localized: "light", bundle: .module, comment: "Settings search: keyword for the Fill Light switch")])
    }

    static var display: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "display",
                        title: String(localized: "Display", bundle: .module,
                                      comment: "Settings ▸ Fill Light: which display gets the Fill Light (pop-up)"))
    }

    static var width: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "width",
                        title: String(localized: "Width", bundle: .module, comment: "Settings ▸ Fill Light: width of the glowing frame (slider)"))
    }

    static var warmth: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "warmth",
                        title: String(localized: "Warmth", bundle: .module, comment: "Settings ▸ Fill Light: color temperature of the light (slider)"),
                        keywords: [String(localized: "color temperature", bundle: .module, comment: "Settings search: keyword for Warmth")])
    }

    static var brightness: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "brightness",
                        title: String(localized: "Brightness", bundle: .module, comment: "Settings ▸ Fill Light: brightness of the light (slider)"),
                        keywords: [PaneWords.brighter])
    }

    static var camera: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "camera",
                        title: String(localized: "Turn on while a camera is in use", bundle: .module, comment: "Settings ▸ Fill Light: switch"),
                        keywords: [PaneWords.camera])
    }

    static var cameras: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "cameras",
                        title: String(localized: "Cameras", bundle: .module,
                                      comment: "Settings ▸ Fill Light: which cameras turn the Fill Light on (pop-up)"),
                        keywords: [PaneWords.camera])
    }

    static var note: SettingsRowInfo {
        SettingsRowInfo(.fillLight, "note",
                        title: String(localized: "Fill Light is left out of screenshots where macOS allows. Some screen-sharing apps may still show it.",
                                      bundle: .module, comment: "Settings ▸ Fill Light: note at the end of the pane"),
                        keywords: [String(localized: "screenshot", bundle: .module, comment: "Settings search: keyword for the Fill Light note")])
    }
}
