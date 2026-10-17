// OverbrightOnboarding/Model/WelcomeChoices.swift — what Done and Skip apply (DESIGN.md §8: "Skip (and closing the
// window) applies every default, including the login item ('Open Overbright, keep it off', registered with
// SMAppService.mainApp). Done applies the choices of step 3."; D16). Seeded by WP0b (ARCHITECTURE.md §10.2) with the
// launch behaviour and the update switch; owned by WP12 (§10.14), which adds the guards of step 3 and step 2's
// "Use extra brightness" switches.
//
// A choice is nil until the person touches it, and a step shows the stored setting meanwhile: on a first run every
// setting is at its default, so the steps show the defaults; Welcome opened again from Settings ▸ About shows what the
// person has. Done writes the touched choices (step 2's switches with the OLED notices accepted for them, step 3's
// guards, step 5's update switch) and applies the launch behaviour (the login item follows it through `AppControl`).
// Skip and the close button drop every choice made in Welcome and apply the default launch behaviour, as DESIGN.md §8
// reads ("applies every default, including the login item"): the login item is registered as "Open Overbright, keep
// it off", also on a later Welcome opened from Settings ▸ About (WP14 C-ONBOARD-5). Nothing else is written: the
// other settings Welcome shows are at their defaults on a first run, and a later Skip leaves them as Settings holds
// them; resetting them is Reset All's job, with its confirmation and Undo (DESIGN.md §7.8).
import Foundation
import Observation
import OverbrightCore

/// The choices made in the Welcome window, and how Done and Skip apply them.
@Observable final class WelcomeChoices {
    /// Step 3's login choice; nil = the stored one (default "Open Overbright, keep it off").
    var launchBehavior: LaunchBehavior?
    /// Step 3's "Pause on battery below …" switch (on = pause below the threshold, off = keep boosting); nil = stored.
    var batteryGuard: BatteryGuard?
    /// Step 3's battery level pop-up, 5…95 in steps of 5; nil = stored (default 20).
    var batteryThreshold: Int?
    /// Step 3's "Pause in Low Power Mode"; nil = stored (default on).
    var pauseInLowPowerMode: Bool?
    /// Step 3's "Pause for full-screen video"; nil = stored (default on).
    var pauseForFullScreenVideo: Bool?
    /// Step 5's "Check for updates on GitHub" (shown only when the build has a repository); nil = stored (default off).
    var checksForUpdates: Bool?
    /// Step 2's "Use extra brightness" switches that differ from what is stored, by display.
    private(set) var extraBrightness: [DisplayKey: Bool] = [:]
    /// The displays whose OLED notice was accepted in step 2; stored with the switch on Done.
    private(set) var acceptedOLEDNotices: Set<DisplayKey> = []

    /// The battery levels the pop-up offers (DESIGN.md §7.5: 5–95 % in steps of 5).
    static let batteryThresholds = Array(stride(from: 5, through: 95, by: 5))

    // MARK: What the steps show

    /// The login choice on screen.
    func launchBehavior(in settings: SettingsStore) -> LaunchBehavior {
        launchBehavior ?? settings[GeneralSettings.launchBehavior]
    }

    /// The battery automation on screen.
    func batteryGuard(in settings: SettingsStore) -> BatteryGuard {
        batteryGuard ?? settings[AutomationSettings.batteryGuard]
    }

    /// The battery level on screen.
    func batteryThreshold(in settings: SettingsStore) -> Int {
        batteryThreshold ?? settings[AutomationSettings.batteryThreshold]
    }

    /// "Pause in Low Power Mode" on screen.
    func pauseInLowPowerMode(in settings: SettingsStore) -> Bool {
        pauseInLowPowerMode ?? settings[AutomationSettings.pauseInLowPowerMode]
    }

    /// "Pause for full-screen video" on screen.
    func pauseForFullScreenVideo(in settings: SettingsStore) -> Bool {
        pauseForFullScreenVideo ?? settings[AutomationSettings.pauseForFullScreenVideo]
    }

    /// "Check for updates on GitHub" on screen.
    func checksForUpdates(in settings: SettingsStore) -> Bool {
        checksForUpdates ?? settings[UpdateSettings.automatic]
    }

    /// The battery switch: on pauses below the level (or keeps "Pause on battery" when that was chosen in Settings).
    func pausesOnBattery(in settings: SettingsStore) -> Bool { batteryGuard(in: settings) != .off }

    /// Turns the battery switch on or off.
    func setPausesOnBattery(_ pauses: Bool, in settings: SettingsStore) {
        let current = batteryGuard(in: settings)
        batteryGuard = pauses ? (current == .off ? .belowThreshold : current) : .off
    }

    /// Picks a battery level; the switch turns on with it (a level only means something while it pauses).
    func setBatteryThreshold(_ percent: Int, in settings: SettingsStore) {
        batteryThreshold = Self.batteryThresholds.min { abs($0 - percent) < abs($1 - percent) } ?? percent
        if batteryGuard(in: settings) == .off { batteryGuard = .belowThreshold }
    }

    /// Turns step 2's switch of `row`'s display on or off; turning it back to what is stored leaves no choice.
    /// `acceptedOLEDNotice` records that the OLED notice was just accepted for it.
    func setExtraBrightness(_ enabled: Bool, for row: WelcomeDisplayRow, acceptedOLEDNotice: Bool = false) {
        extraBrightness[row.key] = enabled == row.storedBoostEnabled ? nil : enabled
        if acceptedOLEDNotice { acceptedOLEDNotices.insert(row.key) }
    }

    // MARK: Ending

    /// Done: the touched choices apply, then the launch behaviour (registering the login item for both "Open" choices).
    func applyOnDone(to services: OverbrightServices) {
        let settings = services.settings
        applyExtraBrightness(to: services)
        if let batteryGuard { settings[AutomationSettings.batteryGuard] = batteryGuard }
        if let batteryThreshold { settings[AutomationSettings.batteryThreshold] = batteryThreshold }
        if let pauseInLowPowerMode { settings[AutomationSettings.pauseInLowPowerMode] = pauseInLowPowerMode }
        if let pauseForFullScreenVideo { settings[AutomationSettings.pauseForFullScreenVideo] = pauseForFullScreenVideo }
        if services.updates.isConfigured, let checksForUpdates { settings[UpdateSettings.automatic] = checksForUpdates }
        services.app?.setLaunchBehavior(launchBehavior(in: settings))
    }

    /// Skip, or the close button: Welcome's own choices are dropped and the default launch behaviour applies, so the
    /// login item is registered as "Open Overbright, keep it off" (DESIGN.md §8), whatever was stored before.
    func applyDefaults(to services: OverbrightServices) {
        services.app?.setLaunchBehavior(GeneralSettings.launchBehavior.defaultValue)
    }

    /// Step 2's switches: each changed display's preference, with the OLED notice accepted for it, as Settings ▸
    /// Displays writes them.
    private func applyExtraBrightness(to services: OverbrightServices) {
        guard !extraBrightness.isEmpty else { return }
        var all = services.settings[DisplaySettings.perDisplay]
        for (key, enabled) in extraBrightness {
            var preferences = all[key] ?? DisplayPreferences()
            preferences.boostEnabled = enabled
            if enabled, acceptedOLEDNotices.contains(key) { preferences.oledNoticeAcknowledged = true }
            if let name = services.displays.facts(for: key)?.name { preferences.lastKnownName = name }
            all[key] = preferences
        }
        services.settings[DisplaySettings.perDisplay] = all
    }
}
