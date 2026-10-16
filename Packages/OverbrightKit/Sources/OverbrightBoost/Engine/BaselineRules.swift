// OverbrightBoost/Engine/BaselineRules.swift — which reads may become a baseline. ARCHITECTURE.md §4.5 invariant 5,
// §4.8 (capture), D26. Pure and nonisolated. Policy's `TableClassifier` judges a read against the expected base; this
// file adds the engine's own rule (never adopt a uniform multiple of the previous baseline or of the profile base) and
// a plausibility floor, so a scaled or broken table can never become the table we restore.
import OverbrightCore
import OverbrightPolicy

/// Decides whether a read table may be captured or adopted as a display's baseline.
nonisolated enum BaselineRules {
    /// The outcome of a capture.
    enum Capture: Hashable, Sendable {
        /// The read becomes the baseline; `foreign` when it differs from the profile base (a calibration loader or a
        /// continued app's curve, journalled `baseline.foreign`).
        case accept(foreign: Bool)
        /// The read is scaled or invalid: do not arm; attribute it (§4.8).
        case reject(TableClass)
    }

    /// A uniform ratio closer to 1 than this is not a scaling (D26: ≥ 1.02 or ≤ 0.98).
    static let minimumScaling = 0.02
    /// Ratios at different indices may differ by this much (relative) and still count as uniform.
    static let ratioTolerance = 0.01
    /// Entries at or above this read back as clamped (a plateau, D26).
    static let clampLevel: Float = 0.9995
    /// Base entries below this are too dark to carry a ratio.
    static let ratioFloor: Float = 0.05

    /// The capture rule of §4.8 for `read` against the expected base and the previous baseline.
    static func capture(_ read: GammaTable, expectedBase: GammaTable, previous: GammaTable?) -> Capture {
        switch TableClassifier.classify(read, expectedBase: expectedBase) {
        case .scaled(let ratio): return .reject(.scaled(ratio: ratio))
        case .invalid: return .reject(.invalid)
        case .matchesBase, .foreign: break
        }
        guard isPlausible(read) else { return .reject(.invalid) }
        if let ratio = uniformRatio(read, to: expectedBase) { return .reject(.scaled(ratio: ratio)) }
        if hasClampedPlateau(read, base: expectedBase) { return .reject(.scaled(ratio: nil)) }
        if let previous, previous.count == read.count, let ratio = uniformRatio(read, to: previous) {
            return .reject(.scaled(ratio: ratio))
        }
        return .accept(foreign: !read.matches(expectedBase, tolerance: EngineTiming.driftTolerance))
    }

    /// Monotonic on every channel, starting at or below 0.1 and ending at or above 0.9 (never all zeros).
    static func isPlausible(_ table: GammaTable) -> Bool {
        guard table.count > 1 else { return false }
        return table.channels.allSatisfy { channel in
            guard let first = channel.first, let last = channel.last, first <= 0.1, last >= 0.9 else { return false }
            return zip(channel, channel.dropFirst()).allSatisfy { $1 >= $0 - 1e-4 }
        }
    }

    /// The common ratio `table ÷ base` when every channel is the same uniform multiple of `base` (at unclamped,
    /// not-too-dark entries) and that ratio is at least `minimumScaling` away from 1; nil otherwise.
    static func uniformRatio(_ table: GammaTable, to base: GammaTable) -> Double? {
        guard table.count == base.count, table.count > 1 else { return nil }
        var ratios: [Double] = []
        for (t, b) in zip(table.channels, base.channels) {
            for (value, reference) in zip(t, b) where reference >= ratioFloor && value < clampLevel {
                ratios.append(Double(value) / Double(reference))
            }
        }
        guard ratios.count >= 4, let low = ratios.min(), let high = ratios.max() else { return nil }
        let ratio = ratios.sorted()[ratios.count / 2]
        guard (high - low) / ratio <= 2 * ratioTolerance, abs(ratio - 1) >= minimumScaling else { return nil }
        return ratio
    }

    /// At least two entries before the last index read as clamped (≥ 0.9995) where the base has none: a clamped
    /// scaled table whose ratio is unknown (D26).
    static func hasClampedPlateau(_ table: GammaTable, base: GammaTable) -> Bool {
        guard table.count == base.count, table.count > 2 else { return false }
        return zip(table.channels, base.channels).contains { t, b in
            zip(t.dropLast(), b.dropLast()).filter { $0 >= clampLevel && $1 < clampLevel }.count >= 2
        }
    }
}
