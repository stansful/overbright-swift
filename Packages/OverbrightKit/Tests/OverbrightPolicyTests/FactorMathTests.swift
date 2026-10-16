// OverbrightPolicyTests/FactorMathTests.swift — light ↔ table factor, and why the default domain never clips.
// ARCHITECTURE.md §5.2, §5.6, §9.1 (property tests with TestSupport's seeded generator).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct FactorMathTests {
    @Test func theSRGBCurveRoundTripsAndIsContinuousAtItsKnee() {
        for g in stride(from: 0.0, through: 4.0, by: 0.001) {
            #expect(abs(FactorMath.decodeSRGB(FactorMath.encodeSRGB(g)) - g) < 1e-9)
        }
        #expect(abs(FactorMath.encodeSRGB(1) - 1) < 1e-12 && FactorMath.encodeSRGB(0) == 0)
        #expect(abs(FactorMath.encodeSRGB(0.0031308) - 0.0031308 * 12.92) < 1e-6)
    }

    /// For all G in [1, 16] and both domains, `lightGain(tableFactor(G)) ≈ G`, and `tableFactor` is monotonic.
    @Test func everyDomainRoundTripsAndIsMonotonic() {
        var random = SeededGenerator(seed: 0x0B21E7)
        for domain in [TransferDomain.encoded, .linear] {
            for _ in 0..<5000 {
                let g = Double.random(in: 1...16, using: &random)
                let f = FactorMath.tableFactor(forLightGain: g, domain: domain)
                #expect(abs(FactorMath.lightGain(forTableFactor: f, domain: domain) - g) < 1e-9 * g)
            }
            var last = -1.0
            for g in stride(from: 0.02, through: 16, by: 0.01) {
                let f = FactorMath.tableFactor(forLightGain: g, domain: domain)
                #expect(f > last)
                last = f
            }
        }
    }

    /// D5: for H in (1, 16], F = tableFactor(0.97·H, .encoded) satisfies F^k ≤ H for every k in [1, 2.4] and
    /// decodeSRGB(F) ≤ H (worst case 0.981·H), so nothing clips under any of those truths.
    @Test func theEncodedDefaultNeverClipsUnderAnyTruthUpTo2Point4() {
        var random = SeededGenerator(seed: 2026)
        var worst = 0.0
        for i in 0..<20_000 {
            let h = i == 0 ? 16 : Double.random(in: 1.000001...16, using: &random)
            let f = FactorMath.tableFactor(forLightGain: FactorMath.headroomMargin * h, domain: .encoded)
            for k in [1.0, 1.8, 2.0, 2.2, 2.33, 2.4, Double.random(in: 1...2.4, using: &random)] {
                #expect(pow(f, k) <= h)
            }
            let srgb = FactorMath.decodeSRGB(f)
            #expect(srgb <= h)
            worst = max(worst, srgb / h)
        }
        #expect(worst < 0.982)                                         // §5.2: the worst case is 0.981·H
        // The v0.1 default (encodeSRGB above white) clipped under a pure 2.4 power: at H 3.2 it wrote 1.636.
        let old = FactorMath.encodeSRGB(FactorMath.headroomMargin * 3.2)
        #expect(abs(old - 1.636) < 0.001 && pow(old, 2.4) > 3.2)
    }

    /// §5.6 worked numbers (M4 Max built-in: Safe ×1.667, Peak ×2.587).
    @Test func workedFactors() {
        func f(_ g: Double) -> Double { FactorMath.tableFactor(forLightGain: g, domain: .encoded) }
        #expect(abs(f(1000.0 / 600) - 1.237) < 0.0005)
        #expect(abs(f(0.97 * 1600 / 600) - 1.486) < 0.0005)
        #expect(abs(f(2.0) - 1.335) < 0.0005 && abs(f(3.104) - 1.603) < 0.0005)    // M1/M2 or Pro Display XDR
        #expect(abs(f(1.940) - 1.318) < 0.0005 && abs(f(1.552) - 1.201) < 0.0005)  // Studio XDR Peak; outdoors Peak
        #expect(abs(f(1.3) - 1.116) < 0.0005 && abs(f(1.704) - 1.249) < 0.0005)    // MSI OLED Safe and Peak
        #expect(FactorMath.tableFactor(forLightGain: 1.667, domain: .linear) == 1.667)
        #expect(FactorMath.headroomMargin == 0.97 && FactorMath.lowerThreshold == 0.98 && FactorMath.boostExponent == 2.4)
    }

    /// §5.6 "Calibration predictions" for the 0.95 patch merging with white: encoded `encodeSRGB(H) ÷ 0.95` vs linear
    /// `H ÷ decodeSRGB(0.95)`; the sweep's pause at 1.15 × the encoded prediction; the linear confirmation factor
    /// `0.97 × H`, above which every code over `encodeSRGB(H) ÷ (0.97 × H)` clips under the encoded truth.
    @Test func calibrationPredictions() {
        let rows: [(h: Double, encoded: Double, linear: Double)] = [(2.667, 1.613, 2.997), (3.2, 1.745, 3.595),
                                                                   (1.6, 1.293, 1.798)]
        for row in rows {
            let encoded = FactorMath.encodeSRGB(row.h) / 0.95
            let linear = row.h / FactorMath.decodeSRGB(0.95)
            #expect(abs(encoded - row.encoded) < 0.0005, "H \(row.h): \(encoded)")
            #expect(abs(linear - row.linear) < 0.0005, "H \(row.h): \(linear)")
        }
        let h = 2.667
        #expect(abs(1.15 * FactorMath.encodeSRGB(h) / 0.95 - 1.855) < 0.0005)
        #expect(abs(FactorMath.headroomMargin * h - 2.587) < 0.0005)
        #expect(abs(FactorMath.encodeSRGB(h) / (FactorMath.headroomMargin * h) - 0.592) < 0.0005)
        // Under the linear truth the same factor delivers 0.97 × H, under the encoded truth it clips: only a
        // confirmed "distinguishable" can therefore select `.linear`.
        #expect(FactorMath.lightGain(forTableFactor: FactorMath.headroomMargin * h, domain: .encoded) > h)
        #expect(FactorMath.lightGain(forTableFactor: FactorMath.headroomMargin * h, domain: .linear) <= h)
    }
}
