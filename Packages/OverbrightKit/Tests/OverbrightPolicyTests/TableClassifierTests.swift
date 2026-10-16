// OverbrightPolicyTests/TableClassifierTests.swift — neutrality judged against the profile base, never the maximum.
// ARCHITECTURE.md D26, §4.5 invariant 5, §4.8, §7.4, §9.1: both read-back models (entries above 1.0 as written, or
// clamped), calibrated (non-identity) bases, uniform multiples, all-zero tables.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct TableClassifierTests {
    private let identity = GammaTable.identity(count: 1024)
    private let calibrated = DisplayFixture.calibratedProfile.displays[0].profileBase ?? .identity(count: 1024)

    private func map(_ table: GammaTable, _ transform: (Float) -> Float) -> GammaTable {
        GammaTable(red: table.red.map(transform), green: table.green.map(transform), blue: table.blue.map(transform))
    }
    private func scaled(_ table: GammaTable, by factor: Double) -> GammaTable { map(table) { $0 * Float(factor) } }
    /// What a clamping read-back returns for `table`.
    private func clamped(_ table: GammaTable) -> GammaTable { map(table) { min($0, 1) } }
    private func classify(_ read: GammaTable, _ base: GammaTable) -> TableClass {
        TableClassifier.classify(read, expectedBase: base)
    }
    private func ratio(_ tableClass: TableClass) -> Double? {
        if case .scaled(let ratio) = tableClass { ratio } else { nil }
    }

    @Test func theBaseMatchesItselfAndSmallNoise() {
        for base in [identity, calibrated, .identity(count: 256)] {
            #expect(classify(base, base) == .matchesBase)
            #expect(classify(clamped(base), base) == .matchesBase)
            var noisy = base
            noisy.green = base.green.enumerated().map { $0.element + ($0.offset.isMultiple(of: 2) ? 0.003 : -0.003) }
            #expect(classify(noisy, base) == .matchesBase)
        }
        // A display's calibrated curve is not neutral against an identity base (a loader without a vcgt profile).
        #expect(classify(calibrated, identity) == .foreign)
    }

    /// Uniform multiples ≥ ×1.02 or ≤ ×0.98 are `scaled` with their ratio, on both bases and both read-back models.
    @Test func uniformMultiplesAreScaledUnderBothReadBackModels() throws {
        let factors = [1.02, 1.03, 1.055, 1.112, 1.237, 1.486, 1.6, 0.98, 0.95, 0.736, 0.422, 0.152]
        for base in [identity, calibrated] {
            for factor in factors {
                let written = scaled(base, by: factor)
                for read in [written, clamped(written)] {
                    let result = classify(read, base)
                    let found = try #require(ratio(result), "×\(factor): \(result)")
                    #expect(abs(found - factor) < 1e-4, "×\(factor)")
                }
            }
        }
        // Between the match tolerance and ±2 % a dim reads as another app's curve, never as neutral or scaled.
        #expect(classify(scaled(identity, by: 0.985), identity) == .foreign)
    }

    /// Property (§9.1), 10 000 seeds: a uniform multiple of a base is never `matchesBase`, and the class (and ratio)
    /// is the same whether or not read-back clamps. Short tables keep it fast; the logic does not depend on length.
    @Test func multiplesNeverMatchAndTheReadBackModelNeverChangesTheClass() {
        let bases = [64, 128].flatMap { count in [GammaTable.identity(count: count), sampled(calibrated, count: count)] }
        for seed in 0..<10_000 {
            var random = SeededGenerator(seed: UInt64(seed))
            let base = bases[Int.random(in: 0..<bases.count, using: &random)]
            let factor = Bool.random(using: &random) ? Double.random(in: 1.02...4, using: &random)
                                                     : Double.random(in: 0.1...0.98, using: &random)
            let written = scaled(base, by: factor)
            let plain = classify(written, base)
            let clampedClass = classify(clamped(written), base)
            #expect(plain != .matchesBase && clampedClass != .matchesBase, "seed \(seed): ×\(factor)")
            #expect(sameCase(plain, clampedClass), "seed \(seed): ×\(factor): \(plain) vs \(clampedClass)")
            if let a = ratio(plain), let b = ratio(clampedClass) { #expect(abs(a - b) < 1e-9, "seed \(seed)") }
        }
        // Foreign, invalid and neutral tables keep their class too.
        for table in [warm(identity), calibrated, identity, zeros(1024), inverted(1024)] {
            #expect(sameCase(classify(table, identity), classify(clamped(table), identity)))
        }
    }

    /// Whites pinned at 1.0 before the last index where the base has none: a boost whose ratio is unknown (a
    /// non-uniform curve, or a gain so large that no sub-1 entry is left above the noise floor).
    @Test func aClampedPlateauIsScaledWithAnUnknownRatio() {
        let exactCurve = GammaTable(red: identity.red.map(boostEncoded), green: identity.green.map(boostEncoded),
                                    blue: identity.blue.map(boostEncoded))
        #expect(classify(exactCurve, identity) == .scaled(ratio: nil))
        #expect(classify(clamped(exactCurve), identity) == .scaled(ratio: nil))
        #expect(classify(clamped(scaled(identity, by: 60)), identity) == .scaled(ratio: nil))
        // A single pinned entry is not a plateau; the last index never counts.
        var oneEntry = identity
        oneEntry.red[1022] = 1
        #expect(classify(oneEntry, identity) == .matchesBase)
        // Pinned whites on a table that is darker elsewhere are another app's curve, not a boost.
        var mixed = warm(identity)
        mixed.red = identity.red.map { min($0 * 1.3, 1) }
        #expect(classify(mixed, identity) == .foreign)
    }

    @Test func perChannelCurvesAreForeign() {
        #expect(classify(warm(identity), identity) == .foreign)
        #expect(classify(warm(calibrated), calibrated) == .foreign)
        var redOnly = identity
        redOnly.red = identity.red.map { $0 * 0.8 }
        #expect(classify(redOnly, identity) == .foreign)
    }

    /// Not monotonic, a channel all ≈ 0 (a failed global restore), or black lifted above 0.1: `invalid`.
    @Test func brokenTablesAreInvalid() {
        #expect(classify(zeros(1024), identity) == .invalid)
        #expect(classify(zeros(1024), calibrated) == .invalid)
        var oneDeadChannel = identity
        oneDeadChannel.blue = Array(repeating: 0, count: 1024)
        #expect(classify(oneDeadChannel, identity) == .invalid)
        #expect(classify(inverted(1024), identity) == .invalid)
        let flat = GammaTable(red: Array(repeating: 0.5, count: 1024), green: Array(repeating: 0.5, count: 1024),
                              blue: Array(repeating: 0.5, count: 1024))
        #expect(classify(flat, identity) == .invalid)
        #expect(classify(GammaTable(red: [], green: [], blue: []), identity) == .invalid)
        #expect(classify(GammaTable(red: [0, 1], green: [0, 0.5, 1], blue: [0, 1]), identity) == .invalid)
        // A quantisation wobble is still monotonic.
        var wobble = scaled(identity, by: 0.5)
        wobble.green[500] -= 0.002
        #expect(ratio(classify(wobble, identity)) != nil)
    }

    /// The base is resampled to the read's length (a 256-entry vcgt against a 1024-entry table).
    @Test func basesOfAnotherLengthAreResampled() {
        #expect(classify(identity, .identity(count: 256)) == .matchesBase)
        #expect(ratio(classify(scaled(identity, by: 1.2), .identity(count: 256))).map { abs($0 - 1.2) < 1e-4 } == true)
        #expect(classify(identity, GammaTable(red: [], green: [], blue: [])) == .matchesBase)      // unusable → identity
    }

    /// The fake port's two read-back models give the same classes for a foreign boost and a restore.
    @Test func throughTheFakePortUnderBothReadBackModels() throws {
        for clamps in [false, true] {
            let port = FakeGammaPort(fixture: .calibratedProfile)
            port.clampsReadBack = clamps
            let id = try #require(DisplayFixture.calibratedProfile.displays.first?.facts.ref.id)
            let base = port.profileBase(of: id, count: port.capacity(of: id))
            #expect(classify(try port.read(id), base) == .matchesBase)
            port.foreignWrite(scaled(base, by: 1.4), to: id)
            #expect(ratio(classify(try port.read(id), base)).map { abs($0 - 1.4) < 1e-4 } == true, "clamps \(clamps)")
            port.simulateProcessDeath()
            #expect(classify(try port.read(id), base) == .matchesBase)
        }
    }

    @Test func plausibleRestores() {
        #expect(TableClassifier.isPlausibleRestore(identity, expectedBase: identity))
        #expect(TableClassifier.isPlausibleRestore(calibrated, expectedBase: identity))            // black 0, white ≥ 0.9
        #expect(TableClassifier.isPlausibleRestore(clamped(scaled(identity, by: 1.3)), expectedBase: identity))
        #expect(!TableClassifier.isPlausibleRestore(zeros(1024), expectedBase: identity))          // the failed restore
        #expect(!TableClassifier.isPlausibleRestore(inverted(1024), expectedBase: identity))
        #expect(!TableClassifier.isPlausibleRestore(scaled(identity, by: 0.5), expectedBase: identity))   // ends at 0.5
        let lifted = map(identity) { 0.15 + 0.85 * $0 }
        #expect(!TableClassifier.isPlausibleRestore(lifted, expectedBase: identity))
        // A base that itself ends low is plausible because it matches.
        let dark = scaled(identity, by: 0.85)
        #expect(TableClassifier.isPlausibleRestore(dark, expectedBase: dark))
    }

    // MARK: Tables

    private func sameCase(_ a: TableClass, _ b: TableClass) -> Bool {
        switch (a, b) {
        case (.matchesBase, .matchesBase), (.foreign, .foreign), (.invalid, .invalid): true
        case (.scaled(let x), .scaled(let y)): (x == nil) == (y == nil)
        default: false
        }
    }
    /// A warm-light tool: red as is, green and blue pulled down.
    private func warm(_ base: GammaTable) -> GammaTable {
        GammaTable(red: base.red, green: base.green.map { $0 * 0.9 }, blue: base.blue.map { $0 * 0.7 })
    }
    /// `table` at `count` entries (every n-th entry; the calibrated fixture is 1024 long).
    private func sampled(_ table: GammaTable, count: Int) -> GammaTable {
        let pick = { (channel: [Float]) in
            (0..<count).map { channel[$0 * (channel.count - 1) / max(count - 1, 1)] }
        }
        return GammaTable(red: pick(table.red), green: pick(table.green), blue: pick(table.blue))
    }
    private func zeros(_ count: Int) -> GammaTable {
        GammaTable(red: Array(repeating: 0, count: count), green: Array(repeating: 0, count: count),
                   blue: Array(repeating: 0, count: count))
    }
    private func inverted(_ count: Int) -> GammaTable {
        let ramp = GammaTable.identity(count: count).red.reversed().map { $0 }
        return GammaTable(red: ramp, green: ramp, blue: ramp)
    }
    /// The exact-curve variant `encode(G · decode(B))` at G 1.667 (§5.4): not a uniform multiple.
    private func boostEncoded(_ value: Float) -> Float {
        Float(FactorMath.encodeSRGB(1.667 * FactorMath.decodeSRGB(Double(value))))
    }
}
