// OverbrightPolicy/Eligibility/EligibilityClassifier.swift — what a display can do (D8). ARCHITECTURE.md §3.10, §6.1.
// Stub until WP1.
import OverbrightCore

/// D8 classifier: tolerant comparisons, no name strings in logic, IORegistry inputs optional. `preferences` carries
/// the OLED override and the calibration record; `machine` decides `compatibilityModeAdvised`.
public nonisolated enum EligibilityClassifier {
    /// The verdict, advisories and class defaults of one display.
    public static func classify(_ facts: DisplayFacts, preferences: DisplayPreferences, reading: HeadroomReading?,
                                machine: MachineIdentity) -> EligibilityResult {
        _ = (facts, preferences, reading, machine)
        return EligibilityResult(verdict: .checking, advisories: [], defaultBoostEnabled: false, defaultMechanism: .table)
    }
}
