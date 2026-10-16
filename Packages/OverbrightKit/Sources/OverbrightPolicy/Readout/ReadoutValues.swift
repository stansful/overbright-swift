// OverbrightPolicy/Readout/ReadoutValues.swift — the numbers behind a card's readout. ARCHITECTURE.md §3.10; DESIGN.md §5.6.
import OverbrightCore

/// Pure numbers behind a card's readout; Design formats them (DESIGN.md §5.6).
public nonisolated struct ReadoutValues: Hashable, Sendable {
    /// What the readout says.
    public enum State: Hashable, Sendable {
        /// Master off.
        case off
        /// At Standard.
        case standard
        /// Waiting for headroom.
        case preparing
        /// Boosting.
        case boost
        /// Dimming.
        case dim
    }
    /// What the readout says.
    public var state: State
    /// The light gain on screen.
    public var appliedGain: Double
    /// Set when the applied gain is below the request ("×1.21 · asked ×1.47").
    public var requestedGain: Double?
    /// Only with a trusted SDR white AND a valid calibration record for the current mechanism.
    public var nits: Double?
    /// The preset at the current level, if any.
    public var preset: LevelPreset?
    /// No valid calibration: the multiplier is shown as an estimate ("≈ ×1.29").
    public var isEstimate: Bool
    /// Dim light as a percentage of Standard (2…99).
    public var dimPercent: Int?
    /// Readout values.
    public init(state: State, appliedGain: Double, requestedGain: Double?, nits: Double?, preset: LevelPreset?,
                isEstimate: Bool, dimPercent: Int?) {
        self.state = state; self.appliedGain = appliedGain; self.requestedGain = requestedGain; self.nits = nits
        self.preset = preset; self.isEstimate = isEstimate; self.dimPercent = dimPercent
    }
}
