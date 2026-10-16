// OverbrightBoost/Writer/GammaTable+Scaling.swift — the plain multiply of a baseline and the table comparisons the
// engine needs. ARCHITECTURE.md §4.8 (sample index, tolerances), §5.4 (`T[i] = B[i] × F`, never above `F × max(B)`),
// D26 (neutrality is judged against the profile base, never by the table maximum). Pure, nonisolated.
import OverbrightCore

extension GammaTable {
    /// The three channels, red first.
    nonisolated var channels: [[Float]] { [red, green, blue] }

    /// Every entry multiplied by `factor` (the plain multiply of §5.4: correct under every transfer domain, and never
    /// above `factor × maximum`).
    nonisolated func scaled(by factor: Double) -> GammaTable {
        let f = Float(factor)
        return GammaTable(red: red.map { $0 * f }, green: green.map { $0 * f }, blue: blue.map { $0 * f })
    }

    /// The largest difference between two entries at the same index over every channel; infinity when the tables
    /// have different lengths.
    nonisolated func maximumDifference(to other: GammaTable) -> Double {
        guard count == other.count, red.count == green.count, red.count == blue.count,
              other.red.count == other.green.count, other.red.count == other.blue.count else { return .infinity }
        var worst = 0.0
        for (mine, theirs) in zip(channels, other.channels) {
            for (a, b) in zip(mine, theirs) { worst = max(worst, abs(Double(a) - Double(b))) }
        }
        return worst
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
