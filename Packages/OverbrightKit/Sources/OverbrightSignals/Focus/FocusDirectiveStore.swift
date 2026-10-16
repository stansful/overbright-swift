// OverbrightSignals/Focus/FocusDirectiveStore.swift — the last Focus filter directive, persisted. ARCHITECTURE.md §3.6
// (`SystemSignals.setFocusDirective`), §7.7 (Focus filter → IntentRouter → Signals), §8.2 (`overbright.engine.
// focusDirective`, a record, not a preference), D18.
// v1 has no extension to receive Focus changes while Overbright is quit, so the app reads `OverbrightFocusFilter.current`
// at launch and passes it on; this store keeps the last directive across launches in between.
// Thread: main (`SettingsStore`).
import OverbrightCore

/// Reads and writes `EngineRecords.focusDirective`.
final class FocusDirectiveStore {
    private let settings: SettingsStore

    /// A store over `settings`.
    init(settings: SettingsStore) { self.settings = settings }

    /// The last directive (`leaveAlone` when none was ever set).
    var directive: FocusDirective {
        get { settings[EngineRecords.focusDirective] }
        set { settings[EngineRecords.focusDirective] = newValue }
    }
}
