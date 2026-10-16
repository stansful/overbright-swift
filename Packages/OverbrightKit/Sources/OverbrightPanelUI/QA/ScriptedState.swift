// OverbrightPanelUI/QA/ScriptedState.swift — one named state of the gallery: the engine status plus what is not part of
// the status (levels, cap modes, linked levels, the per-display switch, calibration records, Fill Light, the expanded
// "Why?" row). DESIGN.md §5.13; ARCHITECTURE.md §8.5 (`--qa-state` drives `PreviewBoostControl` with the status).
import Foundation
import OverbrightCore

/// A named state of the panel, the menu or the HUD.
struct ScriptedState {
    /// The `--qa-state` name.
    let id: String
    /// What the engine publishes.
    let status: BoostStatus
    /// The displays the directory lists (the status's displays, with their facts).
    let facts: [DisplayFacts]
    /// Settings the state needs (levels, cap modes, switches, records).
    var configure: @MainActor (SettingsStore) -> Void = { _ in }
    /// Fill Light is on.
    var fillLightOn = false
    /// The "Why?" row is expanded.
    var expandsWhy = false

    /// A HUD or Keep-this-level state (DESIGN.md §5.13's last row).
    var isHUDState: Bool { id.hasPrefix("hud-") || id == "keep-level" }
}

/// Settings edits the gallery uses.
enum ScriptedSettings {
    /// Sets the stored preferences of `display`.
    @MainActor
    static func set(_ settings: SettingsStore, _ display: DisplayKey, _ change: (inout DisplayPreferences) -> Void) {
        var all = settings[DisplaySettings.perDisplay]
        var preferences = all[display] ?? DisplayPreferences()
        change(&preferences)
        all[display] = preferences
        settings[DisplaySettings.perDisplay] = all
    }

    /// A calibration record that is valid on the owner's Mac (encoded result, the table method).
    static func calibration(potential: Double, sdrWhite: Double? = nil) -> CalibrationRecord {
        CalibrationRecord(outcome: .encoded, mechanism: .table, mergeFactor: 1.62, estimatedExponent: 2.3,
                          measuredSDRWhiteNits: sdrWhite, headroomAtTest: 2.667, potentialAtTest: potential,
                          osBuild: DisplayFixture.ownerMachine.osBuild, measuredAt: ScriptedParts.now)
    }
}
