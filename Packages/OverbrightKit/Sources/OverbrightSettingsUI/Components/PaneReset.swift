// OverbrightSettingsUI/Components/PaneReset.swift — what "Reset ‹Pane›…" does (DESIGN.md §7.2, §12.9). Ported from
// Cranny's PaneFooter.swift (the owner's MIT code).
import Foundation
import OverbrightCore

/// Resets the namespaces of one pane.
enum PaneReset {
    /// Resets every key of `namespaces`, except the records that live there but are no preference a pane shows:
    /// `automations.pausedUntil` (the pause deadline, written only by the engine) and `updates.lastCheck`. Reset All
    /// still clears them. They are written back in the same main-actor turn, so observers (`observe`, SwiftUI) never
    /// see them change.
    ///
    /// Advanced ▸ Trigger method is stored with each display's preferences (`DisplayPreferences.triggerOverride`, in
    /// the displays namespace) but shown in Advanced, so it follows the pane that shows it (WP11's open item, settled by
    /// WP13): Reset Advanced… sets every display's method back to Automatic, and Reset Displays… keeps them.
    static func reset(_ namespaces: [SettingsNamespace], settings: SettingsStore) {
        let restores = [keeping(AutomationSettings.pausedUntil, in: namespaces, settings: settings),
                        keeping(UpdateSettings.lastCheck, in: namespaces, settings: settings),
                        keepingTriggerMethods(in: namespaces, settings: settings)].compactMap { $0 }
        for namespace in namespaces { settings.reset(namespace: namespace) }
        for restore in restores { restore() }
        if namespaces.contains(.advanced) { resetTriggerMethods(settings) }
    }

    /// Every display's trigger method back to Automatic (the rest of its preferences untouched).
    static func resetTriggerMethods(_ settings: SettingsStore) {
        var all = settings[DisplaySettings.perDisplay]
        guard all.values.contains(where: { $0.triggerOverride != nil }) else { return }
        for key in all.keys { all[key]?.triggerOverride = nil }
        settings[DisplaySettings.perDisplay] = all
    }

    /// Reset Displays… keeps the trigger methods Advanced shows: written back after the reset.
    private static func keepingTriggerMethods(in namespaces: [SettingsNamespace],
                                              settings: SettingsStore) -> (@MainActor () -> Void)? {
        guard namespaces.contains(.displays), !namespaces.contains(.advanced) else { return nil }
        let methods = settings[DisplaySettings.perDisplay].compactMapValues(\.triggerOverride)
        guard !methods.isEmpty else { return nil }
        return {
            var all = settings[DisplaySettings.perDisplay]
            for (key, method) in methods {
                var preferences = all[key] ?? DisplayPreferences()
                preferences.triggerOverride = method
                all[key] = preferences
            }
            settings[DisplaySettings.perDisplay] = all
        }
    }

    private static func keeping<V>(_ key: SettingKey<V>, in namespaces: [SettingsNamespace],
                                   settings: SettingsStore) -> (@MainActor () -> Void)? {
        guard namespaces.contains(key.namespace) else { return nil }
        let value = settings[key]
        return { if settings[key] != value { settings[key] = value } }
    }
}
