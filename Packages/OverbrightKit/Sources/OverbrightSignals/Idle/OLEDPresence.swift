// OverbrightSignals/Idle/OLEDPresence.swift — whether the idle source is needed at all. ARCHITECTURE.md §7.1 (idle is
// boost-only AND OLED-only), D8, D22.
// The reducer applies `isIdleBeyondThreshold` to OLED displays only, so on a Mac without one the idle source never
// runs. "OLED" is Policy's own rule (`EligibilityClassifier.isOLED`: the user's override, else the `oledExternal`
// class or an external whose IORegistry minimum luminance is self-emissive; never a name), so the source runs exactly
// where the reducer can apply the idle pause.
// Thread: any (pure).
import OverbrightCore
import OverbrightPolicy

/// Decides whether any online display is OLED.
nonisolated enum OLEDPresence {
    /// True when at least one of `displays` is OLED after the per-display override in `preferences`.
    static func anyOLED(_ displays: [DisplayFacts], preferences: [DisplayKey: DisplayPreferences]) -> Bool {
        displays.contains { facts in
            EligibilityClassifier.isOLED(facts, override: preferences[facts.ref.key]?.oled ?? .automatic)
        }
    }
}
