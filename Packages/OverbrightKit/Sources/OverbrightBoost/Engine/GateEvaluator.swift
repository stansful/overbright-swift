// OverbrightBoost/Engine/GateEvaluator.swift — the gate rules of D6, including the pre-held path. ARCHITECTURE.md
// §4.3 (arming and gating rows), §4.4 (thresholds). Pure and nonisolated: the controller passes the samples and the
// instants in; nothing here reads a clock.
import OverbrightCore
import OverbrightPolicy

/// Decides, from headroom samples, whether a rung moved headroom, whether the gate is ready, and whether a rung or the
/// gate timed out.
nonisolated enum GateEvaluator {
    /// One headroom sample.
    struct Sample: Hashable, Sendable {
        /// When it was read.
        var time: MonotonicInstant
        /// H.
        var headroom: Double
        /// A sample.
        init(time: MonotonicInstant, headroom: Double) { self.time = time; self.headroom = headroom }
    }

    /// Which gate applies.
    enum Path: Hashable, Sendable {
        /// Movement above the idle headroom, then `max(1.1, H0 + 0.1)` and stable.
        case normal
        /// Something already holds EDR: no movement test, `H ≥ 1.1` and stable (D6).
        case preHeld
    }

    /// The outcome of one tick.
    enum Verdict: Hashable, Sendable {
        /// Keep polling.
        case waiting
        /// The first movement (normal path): arming → gating.
        case moved
        /// Ready at this headroom: ramp.
        case ready(headroom: Double)
        /// No movement within the rung timeout after the rung's first successful present.
        case rungTimedOut
        /// Moved (or pre-held) but never stable within the gate timeout.
        case gateTimedOut
    }

    /// The pre-held rule (D6): an own EDR surface on the display, or `H0 ≥ max(1.3, G ÷ 0.97)`, or `H0 ≥ 1.25` with
    /// the idle reads stable within the band (±0.05).
    /// - Parameters:
    ///   - idleReads: the baseline reads (H0 is their maximum).
    ///   - gain: the light gain the level asks for.
    static func isPreHeld(idleReads: [Double], gain: Double, ownSurface: Bool) -> Bool {
        if ownSurface { return true }
        guard let h0 = idleReads.max(), let low = idleReads.min() else { return false }
        if h0 >= max(EngineTiming.preHeldMinimum, gain / FactorMath.headroomMargin) { return true }
        return h0 >= EngineTiming.preHeldStable && h0 - low <= 2 * EngineTiming.stabilityBand
    }

    /// The headroom the gate needs: `max(1.1, H0 + 0.1)` on the normal path, `1.1` pre-held.
    static func readyThreshold(path: Path, idle: Double) -> Double {
        switch path {
        case .normal: max(EngineTiming.readyMinimum, idle + EngineTiming.readyAboveIdle)
        case .preHeld: EngineTiming.readyMinimum
        }
    }

    /// Whether `headroom` is a movement above the idle headroom (`H ≥ H0 + 0.05`).
    static func isMovement(_ headroom: Double, idle: Double) -> Bool {
        headroom >= idle + EngineTiming.movementThreshold - 1e-12
    }

    /// Whether the samples ending at `now` have stayed within the stability band (±0.05: a range of at most 0.1) for
    /// the whole stability window (the run of in-band samples must reach back at least `stabilityWindow`).
    static func isStable(_ samples: [Sample], now: MonotonicInstant) -> Bool {
        guard let latest = samples.last else { return false }
        var low = latest.headroom, high = latest.headroom
        var earliest = latest.time
        for sample in samples.reversed() {
            low = min(low, sample.headroom)
            high = max(high, sample.headroom)
            guard high - low <= 2 * EngineTiming.stabilityBand + 1e-12 else { break }
            earliest = sample.time
        }
        return now - earliest >= EngineTiming.stabilityWindow
    }

    /// One tick of the gate.
    /// - Parameters:
    ///   - samples: readings since the rung was presented (oldest first); the last is the current one.
    ///   - idle: H0.
    ///   - presentedAt: the rung's first successful present (the rung timeout's start).
    ///   - movedAt: the first movement on the normal path; the arming instant on the pre-held path (the gate
    ///     timeout's start); nil while waiting for movement. Stability is always measured from it.
    ///   - gatePause: time the gate timeout stood still (macOS asked to suppress HDR); stability ignores it.
    static func evaluate(path: Path, samples: [Sample], idle: Double, presentedAt: MonotonicInstant,
                                movedAt: MonotonicInstant?, gatePause: Duration = .zero,
                                now: MonotonicInstant) -> Verdict {
        guard let latest = samples.last else {
            return now - presentedAt >= EngineTiming.rungTimeout && path == .normal ? .rungTimedOut : .waiting
        }
        guard let movedAt else {
            if path == .normal, isMovement(latest.headroom, idle: idle) { return .moved }
            return now - presentedAt >= EngineTiming.rungTimeout ? .rungTimedOut : .waiting
        }
        let threshold = readyThreshold(path: path, idle: idle)
        if latest.headroom >= threshold - 1e-12, isStable(samples.filter { $0.time >= movedAt }, now: now) {
            return .ready(headroom: latest.headroom)
        }
        return now - movedAt - gatePause >= EngineTiming.gateTimeout ? .gateTimedOut : .waiting
    }
}

