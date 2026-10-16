// OverbrightPolicy/Reducer/DisplayOutcome.swift — one display's decision plus what the banner and symbol need.
// ARCHITECTURE.md §6.1, §6.3, §6.4.
import OverbrightCore

/// The reducer's result for one display, with the two facts the banner and the symbol are chosen from.
nonisolated struct DisplayOutcome: Hashable, Sendable {
    /// What the engine receives.
    var decision: DisplayDecision
    /// The level is not Standard and the verdict allows that half: without a stop, this display would change.
    var requestsChange: Bool
    /// `requestsChange` on the boost half: this display "should boost" (§6.4).
    var requestsBoost: Bool
}
