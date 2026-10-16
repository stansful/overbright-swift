// OverbrightSignals/Idle/OLEDPresence.swift — whether the idle deadline is needed at all. ARCHITECTURE.md §7.1 (idle is
// boost-only AND OLED-only), D8, D22.
// The reducer applies `isIdleBeyondThreshold` to OLED displays only, so on a Mac without one the idle source never
// runs. A display is OLED when the user's override says so, or, on Automatic, when Displays classified its panel as
// self-emissive (`PanelClass.oledExternal`, from the IORegistry minimum luminance; never from a name).
// Thread: any (pure).
import OverbrightCore

/// Decides whether any online display is OLED.
nonisolated enum OLEDPresence {
    /// True when at least one of `displays` is OLED after the per-display override in `preferences`.
    static func anyOLED(_ displays: [DisplayFacts], preferences: [DisplayKey: DisplayPreferences]) -> Bool {
        displays.contains { facts in
            switch preferences[facts.ref.key]?.oled ?? .automatic {
            case .oled: true
            case .notOLED: false
            case .automatic: facts.panelClass == .oledExternal
            }
        }
    }
}
