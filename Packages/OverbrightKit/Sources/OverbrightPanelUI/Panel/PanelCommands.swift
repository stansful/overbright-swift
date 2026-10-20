// OverbrightPanelUI/Panel/PanelCommands.swift — what the panel's, the card's and the status menu's actions do, in one
// place. ARCHITECTURE.md §3.6 (`BoostControl`, `AppControl`), §4.9, §7.2; DESIGN.md §4.3, §5.3–§5.10, §12.2–§12.4.
// The engine owns levels, pauses and trips; preferences that the UI edits (the per-display switch) are written to the
// settings store; windows are opened through `AppControl`.
import AppKit
import OverbrightCore

/// Performs the actions of the panel and the status menu.
public struct PanelCommands {
    /// The services the actions use.
    public let services: OverbrightServices
    /// Who asks: `.panel` or `.menu` (the HUD never shows for either).
    public let source: ControlSource
    /// Closes the panel before an action opens another window (a no-op for the menu).
    public let close: @MainActor () -> Void
    /// Asks the OLED question of DESIGN.md §12.4 for the named display; true = Turn On.
    public let confirmOLED: @MainActor (String) -> Bool
    /// Opens a System Settings pane (tests record it).
    public let openURL: @MainActor (URL) -> Void

    /// Commands over `services`. Without `confirmOLED` the OLED notice names the configured idle pause.
    public init(services: OverbrightServices, source: ControlSource, close: @escaping @MainActor () -> Void = {},
                confirmOLED: (@MainActor (String) -> Bool)? = nil,
                openURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        self.services = services; self.source = source; self.close = close
        self.confirmOLED = confirmOLED ?? OLEDNotice.confirmer(services.settings); self.openURL = openURL
    }

    /// Runs `action` for `card`'s display.
    public func perform(_ action: CardAction, on card: DisplayCardModel) {
        switch action {
        case .tryAgain: services.boost.retry(card.key)
        case .learnMore(let anchor): showHelp(anchor)
        case .runSelfTest: openSettings(SettingsLinks.selfTest)
        case .turnOnExtraBrightness: setExtraBrightness(true, for: card.key, name: card.name, isOLED: card.isOLED)
        case .openDisplaySettings: openSystemSettings(SettingsLinks.systemDisplays)
        case .changeTaperSetting: openSettings(SettingsLinks.nearFullBrightness)
        case .choosePeak: openSettings(SettingsLinks.limit(of: card.key))
        case .changeRules: openSettings(SettingsLinks.appRules)
        case .editApps: openSettings(SettingsLinks.pausedApps)
        case .continueAnyway(let app): services.boost.continueAnyway(app)
        }
    }

    // MARK: Windows

    /// Overbright's Settings at `link` ("pane" or "pane#row").
    public func openSettings(_ link: String?) {
        close()
        services.app?.openSettings(link)
    }

    /// The Help window at `anchor`.
    public func showHelp(_ anchor: String?) {
        close()
        services.app?.showHelp(anchor: anchor)
    }

    /// The calibration window for `display`.
    public func calibrate(_ display: DisplayKey) {
        close()
        services.app?.showCalibration(for: display)
    }

    /// A System Settings pane ("Open System Settings").
    public func openSystemSettings(_ url: URL?) {
        guard let url else { return }
        close()
        openURL(url)
    }

    /// Quits Overbright (the ramped stop runs in the app delegate).
    public func quit() {
        close()
        services.app?.quit()
    }

    // MARK: Preferences

    /// The per-display switch of extra brightness. Turning it on for an OLED display asks first (once); turning it
    /// off returns a dimmed display to Standard ("Don't Use on This Display", DESIGN.md §4.3). Returns whether the
    /// switch changed.
    @discardableResult
    public func setExtraBrightness(_ enabled: Bool, for display: DisplayKey, name: String, isOLED: Bool) -> Bool {
        var preferences = preferences(of: display)
        if enabled, isOLED, !preferences.oledNoticeAcknowledged {
            guard confirmOLED(name) else { return false }
            preferences.oledNoticeAcknowledged = true
        }
        preferences.boostEnabled = enabled
        store(preferences, for: display)
        if !enabled, currentLevel(of: display).isDim {
            services.boost.setLevel(.standard, for: services.settings[DisplaySettings.linkLevels] ? nil : display,
                                    source: source)
        }
        return true
    }

    /// The stored preferences of `display` (the defaults when none are stored).
    public func preferences(of display: DisplayKey) -> DisplayPreferences {
        services.settings[DisplaySettings.perDisplay][display] ?? DisplayPreferences()
    }

    /// The level the display uses (the linked one while levels are linked).
    public func currentLevel(of display: DisplayKey) -> LevelPosition {
        services.settings[DisplaySettings.linkLevels] ? services.settings[DisplaySettings.linkedLevel]
            : preferences(of: display).level
    }

    private func store(_ preferences: DisplayPreferences, for display: DisplayKey) {
        var all = services.settings[DisplaySettings.perDisplay]
        all[display] = preferences
        services.settings[DisplaySettings.perDisplay] = all
    }
}
