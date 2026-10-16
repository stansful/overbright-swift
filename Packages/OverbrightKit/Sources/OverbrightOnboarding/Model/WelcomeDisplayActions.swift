// OverbrightOnboarding/Model/WelcomeDisplayActions.swift — what step 2's controls do (DESIGN.md §8, §12.1, §12.4):
// the "Use extra brightness" switch writes the display's preference at once, like Settings ▸ Displays (an OLED asks
// first, once: the panel's `OLEDNotice`); a verdict's fix opens Displays settings in System Settings, or Settings ▸
// Displays at the display's Limit row ("Choose Peak…"). Nothing here asks the engine for anything: Welcome never turns
// Overbright on or changes a level before Turn On Overbright (and never writes a table).
import AppKit
import OverbrightCore
import OverbrightPanelUI

/// Step 2's actions.
struct WelcomeDisplayActions {
    /// The services whose settings and app control the actions use.
    let services: OverbrightServices
    /// Asks the OLED question for the named display; true = Turn On.
    var confirmOLED: @MainActor (String) -> Bool = OLEDNotice.confirm
    /// Opens a System Settings pane.
    var openURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }

    /// Turns extra brightness on or off for `row`'s display. Turning it on for an OLED display shows the OLED notice
    /// until it is accepted once; false when the person cancelled it (nothing changes then).
    @discardableResult
    func setExtraBrightness(_ enabled: Bool, for row: WelcomeDisplayRow) -> Bool {
        let settings = services.settings
        var all = settings[DisplaySettings.perDisplay]
        var preferences = all[row.key] ?? DisplayPreferences()
        if enabled, row.isOLED, !preferences.oledNoticeAcknowledged {
            guard confirmOLED(row.name) else { return false }
            preferences.oledNoticeAcknowledged = true
        }
        preferences.boostEnabled = enabled
        preferences.lastKnownName = row.name
        all[row.key] = preferences
        settings[DisplaySettings.perDisplay] = all
        return true
    }

    /// Runs `row`'s fix.
    func performFix(for row: WelcomeDisplayRow) {
        switch row.fix {
        case .openSystemSettings?:
            if let url = SettingsLinks.systemDisplays { openURL(url) }
        case .choosePeak?:
            services.app?.openSettings(SettingsLinks.limit(of: row.key))
        case nil:
            break
        }
    }
}
