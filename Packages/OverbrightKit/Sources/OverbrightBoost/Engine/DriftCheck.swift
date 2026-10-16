// OverbrightBoost/Engine/DriftCheck.swift — classifies a read-back of a scaled or dimmed table. ARCHITECTURE.md §4.8
// (sampling, separation, evaluation order), §4.4 (`driftTolerance`, separation ≥ 2 × tolerance), D9, D26. Pure and
// nonisolated. It compares only entries where `B × F ≤ 0.98`, so it works whether or not read-back clamps at 1.0.
import OverbrightCore

/// The drift check of one tick: which hypothesis explains what the display holds now.
nonisolated enum DriftCheck {
    /// The outcome, in evaluation order.
    enum Verdict: Hashable, Sendable {
        /// Our write is still there.
        case fine
        /// Our write and the baseline cannot be told apart at the sample index (e.g. ×1.02): skip this tick's reset
        /// classification; only the headroom check runs.
        case indistinguishable
        /// The system reset our table to the baseline: reapply with a ramp after 250 ms and count a repair.
        case reset
        /// The table matches a profile base that changed without our seeing an event: an adoption candidate.
        case adoptionCandidate
        /// Anything else: another writer. Count a repair and ask the conflict probe to attribute it.
        case foreign
    }

    /// Entries at or below this (after scaling) are compared (below any possible read-back clamp).
    static let sampleCeiling = 0.98

    /// The highest index `i` with `B[i] × factor ≤ 0.98` on every channel (where ×F and ×1 are furthest apart); nil when
    /// there is none above index 0.
    static func sampleIndex(baseline: GammaTable, factor: Double) -> Int? {
        var index = baseline.count - 1
        while index > 0 {
            if let entries = baseline.entries(at: index), entries.allSatisfy({ $0 * factor <= sampleCeiling + 1e-12 }) {
                return index
            }
            index -= 1
        }
        return nil
    }

    /// Classifies `read` against our write (`baseline × factor`), the baseline and a freshly recomputed profile base.
    /// - Parameters:
    ///   - profileBase: E″, considered only when it differs from the baseline by at least the separation.
    static func evaluate(read: GammaTable, baseline: GammaTable, factor: Double, profileBase: GammaTable?,
                         tolerance: Double = EngineTiming.driftTolerance) -> Verdict {
        guard read.count == baseline.count, let index = sampleIndex(baseline: baseline, factor: factor),
              let b = baseline.entries(at: index), let r = read.entries(at: index) else { return .indistinguishable }
        let w = b.map { $0 * factor }
        let separation = EngineTiming.driftSeparationFactor * tolerance
        func distance(_ x: [Double], _ y: [Double]) -> Double { zip(x, y).map { abs($0 - $1) }.max() ?? .infinity }
        guard distance(w, b) >= separation else { return .indistinguishable }
        if distance(r, w) <= tolerance { return .fine }
        if distance(r, b) <= tolerance { return .reset }
        if let profileBase, profileBase.count == read.count, let e = profileBase.entries(at: index),
           distance(e, b) >= separation, distance(e, w) >= separation, distance(r, e) <= tolerance,
           read.matches(profileBase, tolerance: tolerance) {
            return .adoptionCandidate
        }
        return .foreign
    }
}
