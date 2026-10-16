// OverbrightCore/Model/Policy/DisplayPolicyInput.swift — the reducer's input for one display. ARCHITECTURE.md §3.4, §6.1.

/// The reducer's input for one display.
public nonisolated struct DisplayPolicyInput: Hashable, Sendable {
    /// The display's facts.
    public var facts: DisplayFacts
    /// The display's stored preferences.
    public var preferences: DisplayPreferences
    /// What its controller reports.
    public var feedback: EngineFeedback
    /// Trusted SDR white (colorimeter record, H-N1 panel value, or HDR frame average); nil → nits unknown.
    public var sdrWhite: SDRWhiteEstimate?
    /// One display's input.
    public init(facts: DisplayFacts, preferences: DisplayPreferences, feedback: EngineFeedback,
                sdrWhite: SDRWhiteEstimate?) {
        self.facts = facts; self.preferences = preferences; self.feedback = feedback; self.sdrWhite = sdrWhite
    }
}
