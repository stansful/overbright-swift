// OverbrightBoost/Calibration/CalibrationMath.swift — the numbers of the calibration step wedge and its decision rule.
// ARCHITECTURE.md §5.2 (domains, the decision), §5.6 (worked predictions); DESIGN.md §9. Pure: no clock, no I/O.
//
// The 0.95 patch merges with white where the boosted table first clips at H: at `encodeSRGB(H) ÷ 0.95` if the table works
// on encoded values, at `H ÷ decodeSRGB(0.95)` if it works on linear light (1.613 vs 2.997 at H 2.667). The sweep pauses
// at 1.15 × the encoded prediction and ends at 1.15 × the linear one. A merge nearer the encoded prediction (in log
// space, outside ±15 % of the midpoint) records `.encoded`; nearer the linear one it is only a candidate, recorded
// `.linear` only after the confirmation frame at `0.97 × H` was answered "distinguishable", which is impossible under
// the encoded truth (every code above `encodeSRGB(H) ÷ (0.97 H)` clips there). Everything else is `.inconclusive`.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The calibration's constants, predictions and decision (DESIGN.md §9).
nonisolated enum CalibrationMath {
    // MARK: The pattern

    /// The patch whose merge with white the user marks (Space), from the pattern the window draws.
    static let mergePatch = CalibrationPattern.standard.mergePatch

    // MARK: Steps

    /// Step 1 compares Standard with this light gain, in the safe default domain.
    static let comparisonGain = 1.3
    /// Step 1 flips at most this often (§5.8).
    static let comparisonMinimumInterval: Duration = .milliseconds(1500)
    /// Step 2 raises the factor by this much …
    static let sweepStep = 0.02
    /// … this often; the headroom is read at the same cadence whenever the display is above Standard.
    static let sweepInterval: Duration = .milliseconds(400)
    /// The sweep pauses at this multiple of the encoded prediction …
    static let pauseMultiple = 1.15
    /// … and ends at this multiple of the linear prediction.
    static let capMultiple = 1.15
    /// A merge within this factor of the log-space midpoint of the two predictions is inconclusive.
    static let inconclusiveBand = 1.15
    /// Step 3's frame stays this long.
    static let confirmationDuration: Duration = .seconds(2)
    /// The sweep (pause included) stops after this long.
    static let sweepTimeLimit: Duration = .seconds(60)
    /// The test stops when the grant falls below this fraction of the grant it started with.
    static let headroomDropLimit = 0.95
    /// A colorimeter value outside this range (nits) is not a plausible SDR white and is ignored.
    static let plausibleSDRWhite: ClosedRange<Double> = 20...4000

    // MARK: Predictions

    /// Where the merge patch reaches the clip if the table works on encoded values.
    static func encodedMergeFactor(headroom h: Double) -> Double { FactorMath.encodeSRGB(h) / mergePatch }
    /// Where it reaches the clip if the table works on linear light.
    static func linearMergeFactor(headroom h: Double) -> Double { h / FactorMath.decodeSRGB(mergePatch) }
    /// The sweep waits here for "Keep Going".
    static func pauseFactor(headroom h: Double) -> Double { pauseMultiple * encodedMergeFactor(headroom: h) }
    /// The sweep never goes past this.
    static func sweepCap(headroom h: Double) -> Double { capMultiple * linearMergeFactor(headroom: h) }
    /// `TableWriter`'s ceiling for any calibration factor with a reading of headroom `h`: the sweep's cap, widened by
    /// the 5 % the grant may fall before the session stops (`headroomDropLimit`), so every step of a running session
    /// fits and nothing beyond it ever does (about 1.36 × H).
    static func writeCeiling(headroom h: Double) -> Double { sweepCap(headroom: h) / headroomDropLimit }
    /// Step 3's frame: the linear-domain Peak factor.
    static func linearConfirmationFactor(headroom h: Double) -> Double { FactorMath.headroomMargin * h }
    /// Step 1's boosted factor: ×1.3 light (at most 0.97 × H) in the encoded domain.
    static func comparisonFactor(headroom h: Double) -> Double {
        FactorMath.tableFactor(forLightGain: max(min(comparisonGain, FactorMath.headroomMargin * h), 1),
                               domain: .encoded)
    }

    // MARK: Decision

    /// What a merge factor says on its own.
    enum MergeReading: Hashable, Sendable {
        /// Nearer the encoded prediction.
        case encoded
        /// Nearer the linear prediction: step 3 must confirm it.
        case linearCandidate
        /// Missed, at the end of the sweep, or too close to the midpoint.
        case inconclusive
    }

    /// Reads a merge at `factor` (nil: Space never pressed) for a sweep at headroom `h`.
    static func reading(of factor: Double?, headroom h: Double) -> MergeReading {
        guard let factor, factor.isFinite, factor > 1, h > 1 else { return .inconclusive }
        let midpoint = (encodedMergeFactor(headroom: h) * linearMergeFactor(headroom: h)).squareRoot()
        if factor < midpoint / inconclusiveBand { return .encoded }
        if factor > midpoint * inconclusiveBand, factor < sweepCap(headroom: h) - sweepStep / 2 { return .linearCandidate }
        return .inconclusive
    }

    /// The recorded outcome: `.linear` only for a linear candidate confirmed "distinguishable" in step 3.
    static func outcome(merge: Double?, headroom h: Double, linearConfirmed: Bool?) -> CalibrationRecord.Outcome {
        switch reading(of: merge, headroom: h) {
        case .encoded: .encoded
        case .linearCandidate: linearConfirmed == true ? .linear : .inconclusive
        case .inconclusive: .inconclusive
        }
    }

    /// k̂ = ln H ÷ ln(0.95 · merge), for diagnostics only (§5.2: it never chooses a domain).
    static func estimatedExponent(headroom h: Double, mergeFactor: Double?) -> Double? {
        guard let mergeFactor, h > 1 else { return nil }
        let x = mergePatch * mergeFactor
        guard x > 1 else { return nil }
        return log(h) / log(x)
    }
}
