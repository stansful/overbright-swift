// OverbrightOnboarding/Model/WelcomeDisplayActions.swift — what step 2's controls do (DESIGN.md §8, §12.1, §12.4):
// the "Use extra brightness" switch records its choice in `WelcomeChoices`, which Done writes and Skip drops (DESIGN.md
// §8: Skip applies every default), like step 3's choices; turning it on for an OLED display asks first, once (the
// panel's `OLEDNotice`). A verdict's fix opens Displays settings in System Settings, or Settings ▸ Displays at the
// display's Limit row ("Choose Peak…"). Nothing here asks the engine for anything: Welcome never turns Overbright on
// or changes a level before Turn On Overbright (and never writes a table).
import AppKit
import OverbrightCore
import OverbrightPanelUI

/// Step 2's actions.
struct WelcomeDisplayActions {
    /// The services whose settings and app control the actions use.
    let services: OverbrightServices
    /// Where the switches' choices wait for Done.
    let choices: WelcomeChoices
    /// Asks the OLED question for the named display; true = Turn On (nil: the panel's notice, naming the configured
    /// idle pause).
    var confirmOLED: (@MainActor (String) -> Bool)?
    /// Opens a System Settings pane.
    var openURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }

    /// Turns extra brightness on or off for `row`'s display (a choice Done applies). Turning it on for an OLED
    /// display shows the OLED notice until it was accepted once (stored, or earlier in this Welcome); false when the
    /// person cancelled it (nothing changes then).
    @discardableResult
    func setExtraBrightness(_ enabled: Bool, for row: WelcomeDisplayRow) -> Bool {
        let stored = services.settings[DisplaySettings.perDisplay][row.key]?.oledNoticeAcknowledged ?? false
        let asks = enabled && row.isOLED && !stored && !choices.acceptedOLEDNotices.contains(row.key)
        let confirm = confirmOLED ?? OLEDNotice.confirmer(services.settings)
        if asks, !confirm(row.name) { return false }
        choices.setExtraBrightness(enabled, for: row, acceptedOLEDNotice: asks)
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
