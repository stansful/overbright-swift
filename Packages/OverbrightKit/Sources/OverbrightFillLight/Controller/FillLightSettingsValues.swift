// OverbrightFillLight/Controller/FillLightSettingsValues.swift — the Fill Light's settings read at once, and the
// display they choose. ARCHITECTURE.md §3.8 (`FillLightSettings`), §10.9 ("live updates from settings"), §4.3
// (removal at once); DESIGN.md §7.7 (Display: "Built-in Display (else the main display)").
import CoreGraphics
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

    /// The display the frame shows on among `displays`: the chosen one if it can host the frame, else the built-in
    /// display, else the main display (`main`), else the first. Hardware-mirror members have no screen of their own;
    /// a display in `removed` (just removed, before the directory catches up) is skipped.
    func target(in displays: [DisplayFacts], removed: Set<CGDirectDisplayID>, main: CGDirectDisplayID) -> DisplayRef? {
        let candidates = displays.filter { !$0.isMirrored && !removed.contains($0.ref.id) }
        if let display, let chosen = candidates.first(where: { $0.ref.key == display }) { return chosen.ref }
        if let builtIn = candidates.first(where: \.isBuiltIn) { return builtIn.ref }
        return (candidates.first { $0.ref.id == main } ?? candidates.first)?.ref
    }
}
