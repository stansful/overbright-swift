// OverbrightBoost/Writer/GammaTable+Scaling.swift — the plain multiply of a baseline and the table comparisons the
// engine needs. ARCHITECTURE.md §4.8 (sample index, tolerances), §5.4 (`T[i] = B[i] × F`, never above `F × max(B)`),
// D26 (neutrality is judged against the profile base, never by the table maximum). Pure, nonisolated; vDSP keeps a
// 60 Hz ramp of 3 × 1024 entries cheap.
import Accelerate
import OverbrightCore

extension GammaTable {
    /// The three channels, red first.
    nonisolated var channels: [[Float]] { [red, green, blue] }

    /// Every entry multiplied by `factor` (the plain multiply of §5.4: correct under every transfer domain, and never
    /// above `factor × maximum`).
    nonisolated func scaled(by factor: Double) -> GammaTable {
        let f = Float(factor)
        return GammaTable(red: vDSP.multiply(f, red), green: vDSP.multiply(f, green), blue: vDSP.multiply(f, blue))
    }

    /// Every entry clamped at 1.0: what a clamping read-back returns for this table (D26).
    nonisolated var clampedAtOne: GammaTable {
        GammaTable(red: vDSP.clip(red, to: 0...1), green: vDSP.clip(green, to: 0...1), blue: vDSP.clip(blue, to: 0...1))
    }

    /// The largest difference between two entries at the same index over every channel; infinity when the tables
    /// have different lengths.
    nonisolated func maximumDifference(to other: GammaTable) -> Double {
        guard count == other.count, red.count == green.count, red.count == blue.count,
              other.red.count == other.green.count, other.red.count == other.blue.count else { return .infinity }
        guard count > 0 else { return 0 }
        var worst: Float = 0
        for (mine, theirs) in zip(channels, other.channels) {
            worst = max(worst, vDSP.maximumMagnitude(vDSP.subtract(mine, theirs)))
        }
        return Double(worst)
    }

    /// Whether every entry is within `tolerance` of `other`'s entry at the same index.
    nonisolated func matches(_ other: GammaTable, tolerance: Double) -> Bool {
        maximumDifference(to: other) <= tolerance
    }

    /// The entry of every channel at `index` (red, green, blue), nil when out of range.
    nonisolated func entries(at index: Int) -> [Double]? {
        guard index >= 0, index < red.count, index < green.count, index < blue.count else { return nil }
        return [Double(red[index]), Double(green[index]), Double(blue[index])]
    }
}
