// OverbrightCore/Settings/Keys/AutomationSettings.swift — Settings ▸ Automations. ARCHITECTURE.md §3.8, D10.
import Foundation

/// Settings ▸ Automations.
public nonisolated enum AutomationSettings {
    /// The battery automation.
    public static let batteryGuard = SettingKey(.automations, "batteryGuard", default: BatteryGuard.belowThreshold)
    /// Percent, 5…95 in steps of 5.
    public static let batteryThreshold = SettingKey(.automations, "batteryThreshold", default: 20)
    /// Pause extra brightness in Low Power Mode.
    public static let pauseInLowPowerMode = SettingKey(.automations, "pauseInLowPowerMode", default: true)
    /// Minutes; nil = never. Allowed: 5, 10, 15, 20, 30, 45, 60, 90, 120.
    public static let autoOffMinutes = SettingKey(.automations, "autoOffMinutes", default: Int?.none)
    /// Full-screen window whose owner holds a display-sleep assertion (beta until H-P1).
    public static let pauseForFullScreenVideo = SettingKey(.automations, "pauseForFullScreenVideo", default: false)
    /// Any full-screen window, documents and games included.
    public static let pauseForAllFullScreen = SettingKey(.automations, "pauseForAllFullScreen", default: false)
    /// Pause while a game is frontmost.
    public static let pauseInGames = SettingKey(.automations, "pauseInGames", default: false)
    /// Master switch for the list below (the panel's Auto-pause chip toggles it without losing the list).
    public static let pauseForListedApps = SettingKey(.automations, "pauseForListedApps", default: false)
    /// The per-app pause list.
    public static let pausedApps = SettingKey(.automations, "pausedApps", default: PausedAppDefaults.rules)
    /// "Only allow extra brightness during set hours"; nil = always.
    public static let schedule = SettingKey(.automations, "schedule", default: ScheduleWindow?.none)
    /// Minutes without input before an OLED display pauses extra brightness. Allowed: 1, 2, 5, 10, 15, 30.
    public static let oledIdleMinutes = SettingKey(.automations, "oledIdleMinutes", default: 5)
    /// "Pause for…" deadline. Written only by BoostEngine (`pause`/`resume`, §4.9).
    public static let pausedUntil = SettingKey(.automations, "pausedUntil", default: Date?.none)
}
