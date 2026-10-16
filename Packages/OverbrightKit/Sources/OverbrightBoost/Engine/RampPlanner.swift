// OverbrightBoost/Engine/RampPlanner.swift — the shape of every brightness ramp. ARCHITECTURE.md §5.7 (smoothstep in
// stops, ≈ 60 writes per second, never fewer than 6 steps), D5 (300 ms; Reduce Motion 160 ms; Back to Standard
// 120 ms); DESIGN.md §3.3. Pure and nonisolated.
import Foundation
import OverbrightCore

/// Plans ramps between two light gains: smoothstep in log₂-gain space (equal perceived steps), one write per step.
nonisolated enum RampPlanner {
    /// Which duration a ramp takes.
    enum Kind: Hashable, Sendable {
        /// User and policy changes and every reapply (300 ms).
        case standard
        /// The same under Reduce Motion (160 ms, never a snap).
        case reduceMotion
        /// Back to Standard (120 ms).
        case backToStandard
    }

    /// A planned ramp: the gain of every step (the last one is exactly the target) and the wait before each step, so
    /// the last write lands exactly one ramp duration after the ramp started.
    struct Plan: Hashable, Sendable {
        /// Light gains, one per write.
        var gains: [Double]
        /// Time between two writes.
        var interval: Duration
    }

    /// The duration of `kind`.
    static func duration(_ kind: Kind) -> Duration {
        switch kind {
        case .standard: EngineTiming.rampDuration
        case .reduceMotion: EngineTiming.rampDurationReduceMotion
        case .backToStandard: EngineTiming.rampDurationBackToStandard
        }
    }

    /// Steps for `duration` at `EngineTiming.rampStepsPerSecond`, never fewer than `EngineTiming.minimumRampSteps`.
    static func stepCount(for duration: Duration) -> Int {
        max(EngineTiming.minimumRampSteps, Int((duration.timeInterval * Double(EngineTiming.rampStepsPerSecond)).rounded()))
    }

    /// The smoothstep easing `3t² − 2t³` on 0…1.
    static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// The gains of a ramp from `from` to `to` in `steps` writes: smoothstep in log₂ space, ending exactly at `to`.
    static func gains(from: Double, to: Double, steps: Int) -> [Double] {
        let n = max(steps, 1)
        let start = log2(max(from, 1e-6)), end = log2(max(to, 1e-6))
        return (1...n).map { i in i == n ? to : pow(2, start + (end - start) * smoothstep(Double(i) / Double(n))) }
    }

    /// The plan of a ramp of `kind` from `from` to `to`.
    static func plan(from: Double, to: Double, kind: Kind) -> Plan {
        let duration = duration(kind)
        let steps = stepCount(for: duration)
        return Plan(gains: gains(from: from, to: to, steps: steps), interval: duration / steps)
    }
}
