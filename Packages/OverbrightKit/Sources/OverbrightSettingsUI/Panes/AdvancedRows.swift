// OverbrightSettingsUI/Panes/AdvancedRows.swift — the rows of Settings ▸ Advanced (DESIGN.md §7.8), shared by the pane
// and the search index. "advanced#selfTest" (the panel's Run Self-Test…) opens the self-test sheet there.
import Foundation
import OverbrightCore
import OverbrightDesign

/// The rows of Settings ▸ Advanced.
enum AdvancedRows {
    static var copyDiagnostics: SettingsRowInfo {
        SettingsRowInfo(.advanced, "copyDiagnostics",
                        title: String(localized: "Copy Diagnostics", bundle: .module,
                                      comment: "Settings ▸ Advanced: button that copies a technical report to the clipboard (title case)"),
                        keywords: [PaneWords.diagnostics])
    }

    /// Run Self-Test… (Design's title-case name of the action).
    static var selfTest: SettingsRowInfo {
        SettingsRowInfo(.advanced, "selfTest", title: FixAction.runSelfTest.menuTitle(),
                        keywords: [PaneWords.selfTest, PaneWords.diagnostics])
    }

    static var detailedLogging: SettingsRowInfo {
        SettingsRowInfo(.advanced, "detailedLogging",
                        title: String(localized: "Detailed logging", bundle: .module, comment: "Settings ▸ Advanced: switch"),
                        keywords: [String(localized: "log", bundle: .module, comment: "Settings search: keyword for Detailed logging")])
    }

    static var otherApps: SettingsRowInfo {
        SettingsRowInfo(.advanced, "otherApps",
                        title: String(localized: "Apps that change display colors or brightness", bundle: .module,
                                      comment: "Settings ▸ Advanced: the live list of running apps that also change display colors or brightness"),
                        keywords: [PaneWords.colors, PaneWords.flicker,
                                   String(localized: "conflict", bundle: .module, comment: "Settings search: keyword for the list of other apps")])
    }

    /// One display's trigger method pop-up, labeled with the display's name.
    static func triggerMethod(_ display: DisplayKey, name: String) -> SettingsRowInfo {
        SettingsRowInfo(.advanced, "trigger.\(display.rawValue)", title: name,
                        keywords: [triggerMethodTitle,
                                   String(localized: "headroom", bundle: .module, comment: "Settings search: keyword for the trigger methods (Advanced only)")])
    }

    /// "Trigger method": the section header, and a search keyword of its rows.
    static var triggerMethodTitle: String {
        String(localized: "Trigger method", bundle: .module,
               comment: "Settings ▸ Advanced: section header of the per-display method that unlocks extra range")
    }

    static var forgetMethods: SettingsRowInfo {
        SettingsRowInfo(.advanced, "forgetMethods",
                        title: String(localized: "Forget Learned Methods", bundle: .module,
                                      comment: "Settings ▸ Advanced: button that clears the trigger method each display learned (title case)"),
                        keywords: [triggerMethodTitle])
    }

    static var resetDisplayColors: SettingsRowInfo {
        SettingsRowInfo(.advanced, "resetDisplayColors",
                        title: String(localized: "Reset Display Colors…", bundle: .module,
                                      comment: "Settings ▸ Advanced: button that returns every display to its color profile (title case)"),
                        keywords: [PaneWords.colors,
                                   String(localized: "recovery", bundle: .module, comment: "Settings search: keyword for the recovery rows")])
    }

    static var recoveryNote: SettingsRowInfo {
        SettingsRowInfo(.advanced, "recoveryNote",
                        title: String(localized: "If Overbright ever stops responding, Force Quit it. macOS restores your displays at once.",
                                      bundle: .module, comment: "Settings ▸ Advanced: the recovery note; “Force Quit” is macOS’s own name"),
                        keywords: [String(localized: "force quit", bundle: .module, comment: "Settings search: keyword for the recovery note")])
    }
}
