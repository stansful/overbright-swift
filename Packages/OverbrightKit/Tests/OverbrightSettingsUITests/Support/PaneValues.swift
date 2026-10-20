// OverbrightSettingsUITests/Support/PaneValues.swift — every pane's rows, value rows and action rows in one place, and a
// change for every value row away from its default, so the tests can change and reset each one (DESIGN.md §7.2:
// "every row with a value has Reset to Default").
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSettingsUI

/// The panes' row lists.
@MainActor enum PaneValues {
    /// Every value row of every pane.
    static func values(_ services: OverbrightServices) -> [RowValue] {
        GeneralPane.values(services: services) + DisplaysPane.values(services: services)
            + AutomationsPane.values(services: services) + ShortcutsPane.values(services: services)
            + FillLightPane.values(services: services) + AdvancedPane.values(services: services)
    }

    /// Every row that shows no value of its own (About's rows are all of this kind).
    static func actionRows(_ services: OverbrightServices) -> Set<String> {
        GeneralPane.actionRows.union(DisplaysPane.actionRows(services: services))
            .union(AutomationsPane.actionRows).union(ShortcutsPane.actionRows).union(FillLightPane.actionRows)
            .union(AdvancedPane.actionRows).union(AboutPane.rows(services: services).map(\.id))
    }

    /// A rich setup: the built-in display and the OLED external classified by the engine, the schedule on, an OLED
    /// display known, and the app control that stores what the shell stores.
    static func richServices() -> OverbrightServices {
        let services = TestServices.classified(.russianNames)
        services.app = StoringAppControl(settings: services.settings)
        services.settings[AutomationSettings.schedule] = ScheduleEditing.defaultWindow
        return services
    }

    /// Changes the value of row `id` away from its default; false when the table has no change for it.
    @discardableResult
    static func change(_ id: String, in services: OverbrightServices) -> Bool {
        let settings = services.settings
        let editor = DisplayPreferencesEditor(settings: settings)
        if let (key, field) = displayRow(id, prefix: "displays.") {
            switch field {
            case "extraBrightness": editor.update(key, name: "x") { $0.boostEnabled = false }
            case "level": editor.update(key, name: "x") { $0.level = LevelPosition(0.8) }
            case "limit": editor.update(key, name: "x") { $0.capMode = .peak }
            case "method": editor.update(key, name: "x") { $0.mechanism = .overlay }
            case "calibration": editor.update(key, name: "x") { $0.calibration = FakeCalibrationSession.record(.encoded) }
            case "type": editor.update(key, name: "x") { $0.oled = .notOLED }
            default: return false
            }
            return true
        }
        if let (key, field) = displayRow(id, prefix: "advanced."), field.isEmpty {
            editor.update(key, name: "x") { $0.triggerOverride = .metalOneShot }
            return true
        }
        if id.hasPrefix("shortcuts.shortcut.") {
            let shortcut = ShortcutID(String(id.dropFirst("shortcuts.shortcut.".count)))
            settings[ShortcutSettings.bindings][shortcut] = KeyCombo(keyCode: 0, modifiers: [.command, .option])
            return true
        }
        switch id {
        case "general.launchBehavior": settings[GeneralSettings.launchBehavior] = .dontLaunch
        case "general.menuBarIcon": settings[GeneralSettings.showsMenuBarIcon] = false
        case "general.clickAction": settings[GeneralSettings.clickAction] = .toggle
        case "general.dockIcon": settings[GeneralSettings.showsDockIcon] = true
        case "general.showsHUD": settings[GeneralSettings.showsHUD] = false
        case "general.haptics": settings[GeneralSettings.haptics] = false
        case "general.automaticUpdates": settings[UpdateSettings.automatic] = true
        case "general.prereleases": settings[UpdateSettings.prereleases] = true
        case "displays.linkLevels": settings[DisplaySettings.linkLevels] = true
        case "displays.nearFullBrightness": settings[DisplaySettings.boostOnlyNearFullBrightness] = true
        case "automations.power": settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
        case "automations.batteryThreshold": settings[AutomationSettings.batteryThreshold] = 40
        case "automations.lowPowerMode": settings[AutomationSettings.pauseInLowPowerMode] = false
        case "automations.timer": settings[AutomationSettings.autoOffMinutes] = 30
        case "automations.apps": settings[AutomationSettings.pauseForFullScreenVideo] = false
        case "automations.fullScreenApps": settings[AutomationSettings.pauseForAllFullScreen] = true
        case "automations.games": settings[AutomationSettings.pauseInGames] = true
        case "automations.pausedApps": settings[AutomationSettings.pausedApps] = []
        case "automations.schedule":
            settings[AutomationSettings.schedule] = settings[AutomationSettings.schedule] == nil
                ? ScheduleEditing.defaultWindow : nil
        case "automations.scheduleFrom":
            settings[AutomationSettings.schedule] = ScheduleEditing.setting(start: 600, in: settings[AutomationSettings.schedule])
        case "automations.scheduleTo":
            settings[AutomationSettings.schedule] = ScheduleEditing.setting(end: 1320, in: settings[AutomationSettings.schedule])
        case "automations.oledIdle": settings[AutomationSettings.oledIdleMinutes] = 10
        case "shortcuts.stepSize": settings[ShortcutSettings.stepSize] = .fine
        case "fillLight.display": settings[FillLightSettings.display] = DisplayFixture.Keys.mpg322ux
        case "fillLight.width": settings[FillLightSettings.width] = 64
        case "fillLight.warmth": settings[FillLightSettings.warmth] = 1
        case "fillLight.brightness": settings[FillLightSettings.brightness] = 0.5
        case "fillLight.camera": settings[FillLightSettings.autoWithCamera] = true
        case "fillLight.cameras": settings[FillLightSettings.cameraFilter] = .builtInAndUSB
        case "advanced.detailedLogging": settings[AdvancedSettings.detailedLogging] = true
        case "advanced.otherApps": settings[AdvancedSettings.alwaysContinue] = ["S2-example"]
        default: return false
        }
        return true
    }

    /// "displays.<KEY>.level" → (KEY, "level"); "advanced.trigger.<KEY>" → (KEY, "").
    private static func displayRow(_ id: String, prefix: String) -> (DisplayKey, String)? {
        guard id.hasPrefix(prefix) else { return nil }
        var rest = String(id.dropFirst(prefix.count))
        if prefix == "advanced." {
            guard rest.hasPrefix("trigger.") else { return nil }
            rest = String(rest.dropFirst("trigger.".count))
            return (DisplayKey(rawValue: rest), "")
        }
        let parts = rest.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].count == 36 else { return nil }
        return (DisplayKey(rawValue: parts[0]), parts[1])
    }
}
