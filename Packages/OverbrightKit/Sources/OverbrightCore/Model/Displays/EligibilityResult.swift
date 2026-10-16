// OverbrightCore/Model/Displays/EligibilityResult.swift — the classifier's answer for one display. ARCHITECTURE.md §3.2, D8.

/// Verdict, advisories and class defaults of one display (Policy's `EligibilityClassifier`).
public nonisolated struct EligibilityResult: Hashable, Sendable {
    /// What the display can do.
    public var verdict: DisplayVerdict
    /// Facts shown next to the verdict.
    public var advisories: [Advisory]
    /// Class default of `DisplayPreferences.boostEnabled` (the OLED override is applied before classifying).
    public var defaultBoostEnabled: Bool
    /// The mechanism `automatic` resolves to before calibration.
    public var defaultMechanism: Mechanism
    /// A classification result.
    public init(verdict: DisplayVerdict, advisories: [Advisory], defaultBoostEnabled: Bool,
                defaultMechanism: Mechanism) {
        self.verdict = verdict; self.advisories = advisories
        self.defaultBoostEnabled = defaultBoostEnabled; self.defaultMechanism = defaultMechanism
    }
}
