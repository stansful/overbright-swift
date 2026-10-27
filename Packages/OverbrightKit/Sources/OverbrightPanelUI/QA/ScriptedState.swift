// OverbrightPanelUI/QA/ScriptedState.swift — one named state of the gallery: the engine status plus what is not part of
// the status (levels, cap modes, linked levels, the per-display switch, calibration records, Fill Light, the expanded
// "Why?" row, whether the panel shows external displays). DESIGN.md §5.13; ARCHITECTURE.md §8.5 (`--qa-state` drives `PreviewBoostControl` with the status).
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
    /// The panel shows external displays (Settings' switch on): every state but the `externals-hidden` ones, whose
    /// subject is the default, so the gallery keeps the cards each state is about.
    var showsExternalDisplays = true

    /// A HUD or Keep-this-level state (DESIGN.md §5.13's last row).
    var isHUDState: Bool { id.hasPrefix("hud-") || id == "keep-level" }

    /// The state with every decision carrying the level the reducer would have used (`DisplayDecision.level`,
    /// ARCHITECTURE.md §6.1 step 3): the linked level while levels are linked, else the display's own level from
    /// `configure`'s settings. `Readout.values` names the preset at that level.
    func withDecisionLevels() -> ScriptedState {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        configure(settings)
        let linked = settings[DisplaySettings.linkLevels] ? settings[DisplaySettings.linkedLevel] : nil
        let preferences = settings[DisplaySettings.perDisplay]
        var status = status
        status.displays = status.displays.map { display in
            var display = display
            display.decision?.level = linked ?? preferences[display.key]?.level ?? DisplayPreferences().level
            return display
        }
        return ScriptedState(id: id, status: status, facts: facts, configure: configure, fillLightOn: fillLightOn,
                             expandsWhy: expandsWhy, showsExternalDisplays: showsExternalDisplays)
    }
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

    /// A calibration record that is valid on the owner's Mac (encoded result).
    static func calibration(potential: Double, sdrWhite: Double? = nil) -> CalibrationRecord {
        CalibrationRecord(outcome: .encoded, mergeFactor: 1.62, estimatedExponent: 2.3,
                          measuredSDRWhiteNits: sdrWhite, headroomAtTest: 2.667, potentialAtTest: potential,
                          osBuild: DisplayFixture.ownerMachine.osBuild, measuredAt: ScriptedParts.now)
    }
}
