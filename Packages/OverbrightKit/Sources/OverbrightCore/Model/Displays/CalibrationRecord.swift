// OverbrightCore/Model/Displays/CalibrationRecord.swift — the outcome of the calibration step wedge.
// ARCHITECTURE.md §3.2, §5.2; DESIGN.md §9.
import Foundation

/// The outcome of the calibration step wedge (DESIGN.md §9). Valid only while `osBuild`, `mechanism` and
/// `potentialAtTest` (±5 %) match the current values; otherwise the effective domain is `.encoded` (§5.2).
public nonisolated struct CalibrationRecord: Hashable, Codable, Sendable {
    /// What the calibration concluded.
    public enum Outcome: String, Codable, Sendable {
        /// The merge was near the encoded prediction.
        case encoded
        /// The linear confirmation frame was answered "distinguishable".
        case linear
        /// Late, missed or contradicting answers: the default domain stays.
        case inconclusive
        /// The user said the screen did not get brighter (Compatibility mode is offered, §7.5).
        case notBrighter
    }
    /// `.linear` only after the confirmation frame at the linear-domain Peak factor was answered "distinguishable".
    public var outcome: Outcome
    /// The mechanism measured; a record never carries over to the other mechanism.
    public var mechanism: Mechanism
    /// The table factor at which the 0.95 patch merged with white (nil when the user stopped early).
    public var mergeFactor: Double?
    /// k̂ = ln H ÷ ln(0.95 · mergeFactor). Diagnostics only: never used to choose a domain.
    public var estimatedExponent: Double?
    /// SDR white typed from a colorimeter ("I have a colorimeter"); makes nits and the Safe cap exact.
    public var measuredSDRWhiteNits: Double?
    /// Granted headroom during the test.
    public var headroomAtTest: Double
    /// Potential headroom during the test (the record is valid while the current potential is within ±5 %).
    public var potentialAtTest: Double
    /// `kern.osversion` during the test (the record is valid only on the same build).
    public var osBuild: String
    /// When the calibration finished.
    public var measuredAt: Date
    /// A record as the calibration controller writes it.
    public init(outcome: Outcome, mechanism: Mechanism, mergeFactor: Double?, estimatedExponent: Double?,
                measuredSDRWhiteNits: Double?, headroomAtTest: Double, potentialAtTest: Double, osBuild: String,
                measuredAt: Date) {
        self.outcome = outcome; self.mechanism = mechanism; self.mergeFactor = mergeFactor
        self.estimatedExponent = estimatedExponent; self.measuredSDRWhiteNits = measuredSDRWhiteNits
        self.headroomAtTest = headroomAtTest; self.potentialAtTest = potentialAtTest
        self.osBuild = osBuild; self.measuredAt = measuredAt
    }
}
