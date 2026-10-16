// OverbrightSettingsUI/Panes/DisplayPreferencesEditor.swift — reads and writes one display's preferences in
// `DisplaySettings.perDisplay` (ARCHITECTURE.md §3.8), for Settings ▸ Displays, Advanced's trigger methods and the
// calibration window. A write records the display's current name (`lastKnownName`), so a disconnected display can be
// listed and forgotten by name; an entry that returns to every default is removed, so "Reset to Default" on its last
// changed row leaves nothing stored.
import OverbrightCore

/// Edits `DisplaySettings.perDisplay`.
struct DisplayPreferencesEditor {
    let settings: SettingsStore

    /// The stored preferences of `display` (the defaults when none are stored).
    func preferences(of display: DisplayKey) -> DisplayPreferences {
        settings[DisplaySettings.perDisplay][display] ?? DisplayPreferences()
    }

    /// Changes `display`'s preferences; `name` is remembered for when the display is not connected.
    func update(_ display: DisplayKey, name: String?, _ change: (inout DisplayPreferences) -> Void) {
        var preferences = preferences(of: display)
        change(&preferences)
        var all = settings[DisplaySettings.perDisplay]
        if Self.isDefault(preferences) {
            all[display] = nil
        } else {
            if let name, !name.isEmpty { preferences.lastKnownName = name }
            all[display] = preferences
        }
        settings[DisplaySettings.perDisplay] = all
    }

    /// Removes everything stored for `display` ("Forget").
    func forget(_ display: DisplayKey) {
        var all = settings[DisplaySettings.perDisplay]
        all[display] = nil
        settings[DisplaySettings.perDisplay] = all
    }

    /// Displays with stored preferences that are not online now, by key ("Not connected").
    func remembered(online: [DisplayKey]) -> [(key: DisplayKey, preferences: DisplayPreferences)] {
        let online = Set(online)
        return settings[DisplaySettings.perDisplay].filter { !online.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, preferences: $0.value) }
    }

    /// Every preference at its default (the remembered name aside).
    static func isDefault(_ preferences: DisplayPreferences) -> Bool {
        var unnamed = preferences
        unnamed.lastKnownName = nil
        return unnamed == DisplayPreferences()
    }
}
