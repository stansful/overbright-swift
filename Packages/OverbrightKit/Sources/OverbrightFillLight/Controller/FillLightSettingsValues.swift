// OverbrightFillLight/Controller/FillLightSettingsValues.swift — the Fill Light's settings read at once.
// ARCHITECTURE.md §3.8 (`FillLightSettings`), §10.9 ("live updates from settings"); DESIGN.md §7.7.
import OverbrightCore

/// The `fillLight.*` settings the controller follows. Reading them inside `observe` tracks exactly these keys.
nonisolated struct FillLightSettingsValues: Equatable, Sendable {
    /// The chosen display; nil = the built-in display, else the main display.
    var display: DisplayKey?
    /// Points, 16…120.
    var width: Double
    /// 0 = 6 500 K … 1 = 3 000 K.
    var warmth: Double
    /// 0.2…1.
    var brightness: Double
    /// "Turn on while a camera is in use".
    var followsCamera: Bool

    /// The current values of `settings`.
    @MainActor static func read(_ settings: SettingsStore) -> FillLightSettingsValues {
        FillLightSettingsValues(display: settings[FillLightSettings.display], width: settings[FillLightSettings.width],
                                warmth: settings[FillLightSettings.warmth],
                                brightness: settings[FillLightSettings.brightness],
                                followsCamera: settings[FillLightSettings.autoWithCamera])
    }
}
