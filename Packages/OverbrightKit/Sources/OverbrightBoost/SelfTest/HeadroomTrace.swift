// OverbrightBoost/SelfTest/HeadroomTrace.swift — what a series of headroom readings says about one rung: movement,
// stability, how long the grant held. ARCHITECTURE.md §4.4 (gate thresholds, D6), §8.4 (self-test verdicts). Pure: the
// self-test and the calibration's arm feed it samples; no clock, no I/O.
import OverbrightCore

/// Headroom samples of one rung, judged with the gate rules of D6 (§4.4): movement at H0 + 0.05; ready at
/// max(1.1, H0 + 0.1) (1.1 when pre-held); stable within ±0.05 over 1.5 s.
nonisolated struct HeadroomTrace: Hashable, Sendable {
    /// One reading, in seconds since the rung's first successful present.
    struct Point: Hashable, Sendable {
        /// Seconds since the present.
        var seconds: Double
        /// The granted headroom H.
        var headroom: Double
    }

    /// Below this fraction of the time after it became stable, a grant counts as dropped.
    static let heldMinimum = 0.9

    /// H0: the highest baseline read.
    let baseline: Double
    /// Something else already held EDR before the rung was shown (D6): the rung cannot be judged.
    let isPreHeld: Bool
    /// Samples, oldest first.
    private(set) var points: [Point] = []
    /// Seconds of the first sample at or above the movement threshold.
    private(set) var firstMovement: Double?
    /// Seconds at which the samples of the last stability window were first all ready and within the band.
    private(set) var firstStable: Double?

    /// A trace over the baseline reads taken before the rung was shown (at least one).
    init(baselineReads: [Double]) {
        let h0 = baselineReads.max() ?? 1
        baseline = h0
        let spread = (baselineReads.max() ?? 0) - (baselineReads.min() ?? 0)
        isPreHeld = h0 >= EngineTiming.preHeldMinimum
            || (h0 >= EngineTiming.preHeldStable && spread <= 2 * EngineTiming.stabilityBand)
    }

    /// H at which the rung counts as having moved.
    var movementThreshold: Double { baseline + EngineTiming.movementThreshold }
    /// H at which the grant counts as ready.
    var readyThreshold: Double {
        isPreHeld ? EngineTiming.readyMinimum : max(EngineTiming.readyMinimum, baseline + EngineTiming.readyAboveIdle)
    }

    /// Adds a sample (seconds must not go backwards).
    mutating func append(seconds: Double, headroom: Double) {
        points.append(Point(seconds: seconds, headroom: headroom))
        if firstMovement == nil, headroom >= movementThreshold { firstMovement = seconds }
        if firstStable == nil, isStableNow { firstStable = seconds }
    }

    /// The samples of the last 1.5 s are all ready and within ±0.05 of the latest, and they cover the whole window.
    var isStableNow: Bool {
        guard let last = points.last else { return false }
        let window = EngineTiming.stabilityWindow.timeInterval
        guard let first = points.first, last.seconds - first.seconds >= window - 0.000_001 else { return false }
        let recent = points.reversed().prefix { last.seconds - $0.seconds <= window + 0.000_001 }
        return recent.allSatisfy {
            $0.headroom >= readyThreshold && abs($0.headroom - last.headroom) <= EngineTiming.stabilityBand
        }
    }

    /// The fraction of the samples from the first stable moment on that kept the grant (0 if it never was stable).
    var heldFraction: Double {
        guard let stable = firstStable else { return 0 }
        let after = points.filter { $0.seconds >= stable }
        guard !after.isEmpty else { return 0 }
        let held = after.filter { $0.headroom >= readyThreshold - EngineTiming.stabilityBand }.count
        return Double(held) / Double(after.count)
    }

    /// Pre-held → invalid baseline; never moved → no engage; never stable or not held ≥ 90 % → engaged but dropped;
    /// else held.
    var verdict: SelfTestStrategyResult.Verdict {
        if isPreHeld { return .invalidBaseline }
        guard firstMovement != nil else { return .noEngage }
        guard firstStable != nil, heldFraction >= Self.heldMinimum else { return .engagedButDropped }
        return .held
    }
}
