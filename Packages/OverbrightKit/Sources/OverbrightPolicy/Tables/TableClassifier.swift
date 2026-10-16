// OverbrightPolicy/Tables/TableClassifier.swift — classifies a read table against the expected base. ARCHITECTURE.md
// §3.10, §4.5 invariant 5, §4.8, §7.4, D26. One test serves the launch rescue, the post-restore check, `--monitor`'s
// flag and baseline acceptance, under either read-back model (entries above 1.0 read back as written, or clamped).
import OverbrightCore

/// D26: classifies a read table against the display's expected (profile) base. Never uses the table maximum.
/// `.scaled` = a uniform ratio ≥ 1.02 or ≤ 0.98 at sub-1 sample indices on all channels, or a plateau of ≥ 2 entries
/// ≥ 0.9995 before the last index where the base has none; `.invalid` = not monotonic, a channel all ≈ 0, or black
/// lifted above 0.1 where the base starts below it; else `.foreign` (a per-channel curve: a warm-light tool, a
/// calibration loader, an accessibility filter). A dimmed or warm table ends below 0.9 legitimately, so "ends below
/// 0.9" is a reason only for `isPlausibleRestore`, never for `.invalid`.
public nonisolated enum TableClassifier {
    /// Largest difference, per entry, between two tables that are "the same" (read-back noise is ≤ 0.003, §4.4).
    public static let matchTolerance = 0.01
    /// A uniform ratio counts as scaled from this distance from 1 on (1.02 and 0.98 = twice the match tolerance, so a
    /// scaled table can never also match its base).
    public static let minimumScaleDeviation = 0.02
    /// Entries at or above this read as "at full white": the clamp of the clamping read-back model.
    public static let clampLevel = 0.9995
    /// A plateau of at least this many clamped entries before the last index, where the base has none, is a boost.
    public static let plateauEntries = 2
    /// A decrease larger than this between neighbouring entries makes a table non-monotonic (quantisation noise
    /// stays far below it).
    public static let monotonicTolerance = 0.005
    /// A channel whose every entry is at or below this is "all zero" (a failed restore, D7).
    public static let zeroLevel = 0.01
    /// Ratios are fitted only where the base is at least this bright (near black, ratios are noise).
    public static let ratioSampleFloor = 0.02
    /// Black: a plausible table starts at or below this.
    public static let blackLimit = 0.1
    /// White: a plausible restored table ends at or above this.
    public static let whiteLimit = 0.9
    /// Tables hold `Float`s: a ×1.02 written as `Float` reads back as 1.0199999…, which is still ×1.02.
    private static let floatSlack = 1e-5

    /// The class of `read` against `expectedBase` (resampled to `read`'s length when the lengths differ).
    public static func classify(_ read: GammaTable, expectedBase: GammaTable) -> TableClass {
        guard let table = channels(read) else { return .invalid }
        let base = aligned(expectedBase, count: table[0].count)
        if table.contains(where: isAllZero) { return .invalid }
        if matches(table, base) { return .matchesBase }
        if !table.allSatisfy(isMonotonic) { return .invalid }
        if let ratio = uniformRatio(table, base), abs(ratio - 1) >= minimumScaleDeviation - floatSlack {
            return .scaled(ratio: ratio)
        }
        if hasClampedPlateau(table, base) { return .scaled(ratio: nil) }
        if zip(table, base).contains(where: { read, base in read[0] > blackLimit && base[0] <= blackLimit }) {
            return .invalid
        }
        return .foreign
    }

    /// Post-restore check (§7.4): `matchesBase`, or monotonic with every channel starting ≤ 0.1 and ending ≥ 0.9 (and
    /// none all zero). A plausible table can still be `scaled`; the rescue checks that separately.
    public static func isPlausibleRestore(_ read: GammaTable, expectedBase: GammaTable) -> Bool {
        if classify(read, expectedBase: expectedBase) == .matchesBase { return true }
        guard let table = channels(read) else { return false }
        return table.allSatisfy { channel in
            !isAllZero(channel) && isMonotonic(channel)
                && (channel.first ?? 1) <= blackLimit && (channel.last ?? 0) >= whiteLimit
        }
    }

    // MARK: Shape

    /// The three channels in Double, or nil when they are empty or of different lengths.
    private static func channels(_ table: GammaTable) -> [[Double]]? {
        let channels = [table.red, table.green, table.blue].map { $0.map(Double.init) }
        guard let count = channels.first?.count, count > 0, channels.allSatisfy({ $0.count == count }) else {
            return nil
        }
        return channels
    }

    /// `base`'s channels at `count` entries (linear resampling); identity when the base is unusable.
    private static func aligned(_ base: GammaTable, count: Int) -> [[Double]] {
        guard let channels = channels(base) else {
            return Array(repeating: GammaTable.identity(count: count).red.map(Double.init), count: 3)
        }
        guard channels[0].count != count else { return channels }
        return channels.map { resample($0, count: count) }
    }

    private static func resample(_ values: [Double], count: Int) -> [Double] {
        guard values.count > 1, count > 1 else { return Array(repeating: values.first ?? 0, count: count) }
        return (0..<count).map { index in
            let position = Double(index) * Double(values.count - 1) / Double(count - 1)
            let lower = min(Int(position), values.count - 2)
            let fraction = position - Double(lower)
            return values[lower] + (values[lower + 1] - values[lower]) * fraction
        }
    }

    private static func isAllZero(_ channel: [Double]) -> Bool { channel.allSatisfy { $0 <= zeroLevel } }

    private static func isMonotonic(_ channel: [Double]) -> Bool {
        zip(channel, channel.dropFirst()).allSatisfy { previous, next in next >= previous - monotonicTolerance }
    }

    private static func matches(_ table: [[Double]], _ base: [[Double]]) -> Bool {
        zip(table, base).allSatisfy { read, base in
            zip(read, base).allSatisfy { abs($0 - $1) <= matchTolerance }
        }
    }

    // MARK: Scaled

    /// The one ratio that explains every channel as `base × ratio` (entries at full white may be clamped), or nil.
    /// Fitted by least squares over the sub-1 entries where the base is above the noise floor, so both read-back
    /// models give the same ratio.
    private static func uniformRatio(_ table: [[Double]], _ base: [[Double]]) -> Double? {
        var products = 0.0, squares = 0.0
        for (read, base) in zip(table, base) {
            let samples = zip(read, base).filter { read, base in base >= ratioSampleFloor && read < clampLevel }
            guard !samples.isEmpty else { return nil }
            for (r, b) in samples { products += r * b; squares += b * b }
        }
        guard squares > 0 else { return nil }
        let ratio = products / squares
        let explained = zip(table, base).allSatisfy { read, base in
            zip(read, base).allSatisfy { read, base in fits(read, predicted: ratio * base) }
        }
        return explained ? ratio : nil
    }

    /// `read` is what a table entry of `predicted` reads back as, under either read-back model.
    private static func fits(_ read: Double, predicted: Double) -> Bool {
        if read < clampLevel { return abs(read - predicted) <= matchTolerance }
        if read <= 1 + matchTolerance { return predicted >= read - matchTolerance }   // at white: maybe clamped
        return abs(read - predicted) <= matchTolerance * max(predicted, 1)          // above white, as written
    }

    /// ≥ 2 entries at full white before the last index where the base has none, on a table that is nowhere darker
    /// than its base: whites pinned by a boost whose ratio is unknown (clamped read-back, or a non-uniform boost).
    private static func hasClampedPlateau(_ table: [[Double]], _ base: [[Double]]) -> Bool {
        let brightening = zip(table, base).allSatisfy { read, base in
            zip(read, base).allSatisfy { $0 >= $1 - matchTolerance }
        }
        guard brightening else { return false }
        return zip(table, base).contains { read, base in
            let pinned = zip(read.dropLast(), base.dropLast()).filter { read, base in
                read >= clampLevel && base < clampLevel
            }
            return pinned.count >= plateauEntries
        }
    }
}
