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
    static func reset(_ namespaces: [SettingsNamespace], settings: SettingsStore) {
        let restores = [keeping(AutomationSettings.pausedUntil, in: namespaces, settings: settings),
                        keeping(UpdateSettings.lastCheck, in: namespaces, settings: settings)].compactMap { $0 }
        for namespace in namespaces { settings.reset(namespace: namespace) }
        for restore in restores { restore() }
    }

    private static func keeping<V>(_ key: SettingKey<V>, in namespaces: [SettingsNamespace],
                                   settings: SettingsStore) -> (@MainActor () -> Void)? {
        guard namespaces.contains(key.namespace) else { return nil }
        let value = settings[key]
        return { if settings[key] != value { settings[key] = value } }
    }
}
