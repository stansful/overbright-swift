// OverbrightBoostTests/Safety/ReferenceTableClassifier.swift — the D26 rules as a test double, so the launch rescue's
// decisions are tested before WP1's `TableClassifier` body lands (the same idea as TestSupport's reference reducer).
// ARCHITECTURE.md D26, §3.10, §7.4. Suites that run against the real classifier are enabled once it is no longer the
// WP0a stub (`PolicyClassifierProbe`).
import OverbrightCore
import OverbrightPolicy

/// D26 in its plainest form: never judged by the maximum, the same class under both read-back models.
nonisolated enum ReferenceTableClassifier {
    /// Entries within this of the base match it.
    static let matchTolerance: Float = 0.002
    /// Ratios within this (relative) count as one uniform ratio.
    static let ratioTolerance = 0.005
    /// Read-back may clamp here (D26).
    static let clampLevel: Float = 0.9995

    /// `matchesBase`, `scaled(ratio)` (a uniform ratio ≥ 1.02 or ≤ 0.98 at sub-1 indices, or a clamped plateau),
    /// `invalid` (not monotonic, all ≈ 0, starts above 0.1 or ends below 0.9), else `foreign`.
    static func classify(_ read: GammaTable, expectedBase base: GammaTable) -> TableClass {
        guard read.count == base.count, read.count > 1 else { return .invalid }
        let channels = [(read.red, base.red), (read.green, base.green), (read.blue, base.blue)]
        if channels.allSatisfy({ pair in zip(pair.0, pair.1).allSatisfy { abs($0 - $1) <= matchTolerance } }) {
            return .matchesBase
        }
        if channels.allSatisfy({ $0.0.allSatisfy { $0 <= 0.001 } }) { return .invalid }       // all ≈ 0
        var ratios: [Double] = []
        for (r, b) in channels {
            for i in r.indices where b[i] > 0.05 && r[i] < clampLevel { ratios.append(Double(r[i]) / Double(b[i])) }
        }
        if let first = ratios.first, ratios.count >= 3,
           ratios.allSatisfy({ abs($0 - first) <= ratioTolerance * first }), first >= 1.02 || first <= 0.98 {
            return .scaled(ratio: first)
        }
        if channels.allSatisfy({ hasPlateau($0.0, base: $0.1) }) { return .scaled(ratio: nil) }
        if channels.contains(where: { !isPlausibleCurve($0.0) }) { return .invalid }
        return .foreign
    }

    /// The post-restore check: `matchesBase`, or monotonic from ≤ 0.1 to ≥ 0.9 on every channel.
    static func isPlausibleRestore(_ read: GammaTable, expectedBase base: GammaTable) -> Bool {
        classify(read, expectedBase: base) == .matchesBase
            || [read.red, read.green, read.blue].allSatisfy(isPlausibleCurve)
    }

    private static func isPlausibleCurve(_ curve: [Float]) -> Bool {
        guard let first = curve.first, let last = curve.last else { return false }
        return first <= 0.1 && last >= 0.9 && zip(curve, curve.dropFirst()).allSatisfy { $1 >= $0 - 0.0001 }
    }

    /// ≥ 2 entries at the clamp level before the last index, where the base has none.
    private static func hasPlateau(_ read: [Float], base: [Float]) -> Bool {
        let inner = read.indices.dropLast()
        let plateau = inner.filter { read[$0] >= clampLevel }.count
        let basePlateau = inner.filter { base[$0] >= clampLevel }.count
        return plateau >= 2 && basePlateau == 0
    }
}

/// Whether `TableClassifier` and `isPlausibleRestore` are WP1's bodies rather than the WP0a stubs (which call every
/// table `matchesBase` and every restore plausible).
nonisolated enum PolicyClassifierProbe {
    /// True once an all-zero table classifies `invalid` against identity.
    static var isReal: Bool {
        let zero = [Float](repeating: 0, count: 16)
        let zeros = GammaTable(red: zero, green: zero, blue: zero)
        return TableClassifier.classify(zeros, expectedBase: .identity(count: 16)) == .invalid
            && !TableClassifier.isPlausibleRestore(zeros, expectedBase: .identity(count: 16))
    }
}

nonisolated extension GammaTable {
    /// Every entry × `factor` (what a boost or a dim leaves in the table).
    func scaled(by factor: Float) -> GammaTable {
        GammaTable(red: red.map { $0 * factor }, green: green.map { $0 * factor }, blue: blue.map { $0 * factor })
    }

    /// An all-zero table (the failed global restore of D7).
    static func zeros(count: Int) -> GammaTable {
        let zero = [Float](repeating: 0, count: count)
        return GammaTable(red: zero, green: zero, blue: zero)
    }

    /// A warm per-channel curve (blue lowered) that is neither the base nor a uniform multiple of it.
    func warmed() -> GammaTable {
        GammaTable(red: red, green: green.map { $0 * 0.97 }, blue: blue.enumerated().map { i, v in
            v * (0.80 + 0.1 * Float(i) / Float(Swift.max(count - 1, 1)))
        })
    }
}
