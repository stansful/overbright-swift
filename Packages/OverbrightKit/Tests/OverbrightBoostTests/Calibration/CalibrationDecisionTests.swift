// OverbrightBoostTests/Calibration/CalibrationDecisionTests.swift — the calibration's predictions and decision rule
// reproduce ARCHITECTURE.md §5.2 and §5.6 (§10.7 acceptance: 1.61 → encoded; 3.00 → linear only after
// "distinguishable"; late, missed or capped → inconclusive), first as pure math, then through a running session.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct CalibrationDecisionTests {
    private let h = 1600.0 / 600                                     // the M4 Max built-in indoors: 2.667

    private func rounded(_ x: Double, _ places: Double = 3) -> Double {
        let scale = pow(10, places)
        return (x * scale).rounded() / scale
    }

    // MARK: §5.6 numbers

    /// §5.6 quotes H to three decimals (2.667 for 1600 ÷ 600).
    @Test(arguments: [(2.667, 1.613, 2.997), (3.2, 1.745, 3.595), (1.6, 1.293, 1.798)])
    func predictionsMatchTheWorkedNumbers(headroom: Double, encoded: Double, linear: Double) {
        #expect(rounded(CalibrationMath.encodedMergeFactor(headroom: headroom)) == encoded)
        #expect(rounded(CalibrationMath.linearMergeFactor(headroom: headroom)) == linear)
    }

    @Test func pauseCapAndConfirmationFrameMatchTheWorkedNumbers() {
        #expect(rounded(CalibrationMath.pauseFactor(headroom: h)) == 1.855)
        #expect(rounded(CalibrationMath.sweepCap(headroom: h), 2) == 3.45)
        #expect(rounded(CalibrationMath.linearConfirmationFactor(headroom: h)) == 2.587)
        // Under the encoded truth every code above 0.592 clips in the confirmation frame, 0.95 and 1.0 included.
        let clip = FactorMath.encodeSRGB(h) / CalibrationMath.linearConfirmationFactor(headroom: h)
        #expect(clip > 0.592 && clip < 0.593)
        // Step 1 shows ×1.3 light in the safe default domain.
        #expect(rounded(CalibrationMath.comparisonFactor(headroom: h)) == rounded(pow(1.3, 1 / 2.4)))
        #expect(CalibrationMath.comparisonFactor(headroom: 1.2) == pow(0.97 * 1.2, 1 / 2.4))
    }

    // MARK: The rule

    @Test func theAcceptanceCases() {
        #expect(CalibrationMath.outcome(merge: 1.61, headroom: h, linearConfirmed: nil) == .encoded)
        #expect(CalibrationMath.outcome(merge: 3.00, headroom: h, linearConfirmed: true) == .linear)
        #expect(CalibrationMath.outcome(merge: 3.00, headroom: h, linearConfirmed: nil) == .inconclusive)
        #expect(CalibrationMath.outcome(merge: 3.00, headroom: h, linearConfirmed: false) == .inconclusive)
        #expect(CalibrationMath.outcome(merge: 2.20, headroom: h, linearConfirmed: true) == .inconclusive)  // late
        #expect(CalibrationMath.outcome(merge: nil, headroom: h, linearConfirmed: true) == .inconclusive)   // missed
        let cap = CalibrationMath.sweepCap(headroom: h)
        #expect(CalibrationMath.outcome(merge: cap, headroom: h, linearConfirmed: true) == .inconclusive)   // capped
        #expect(CalibrationMath.outcome(merge: 1.70, headroom: h, linearConfirmed: nil) == .encoded)       // a slow press
    }

    @Test func theExponentIsKeptForDiagnosticsOnly() throws {
        #expect(try rounded(#require(CalibrationMath.estimatedExponent(headroom: h, mergeFactor: 1.613)), 2) == 2.30)
        #expect(try rounded(#require(CalibrationMath.estimatedExponent(headroom: h, mergeFactor: 1.70)), 2) == 2.05)
        #expect(try rounded(#require(CalibrationMath.estimatedExponent(headroom: h, mergeFactor: 2.997)), 2) == 0.94)
        #expect(CalibrationMath.estimatedExponent(headroom: h, mergeFactor: nil) == nil)
        #expect(CalibrationMath.estimatedExponent(headroom: h, mergeFactor: 1.02) == nil)   // 0.95 × 1.02 < 1
    }

    /// For every headroom from 1.6 to 16 the encoded prediction reads encoded, the linear one is only a candidate,
    /// the midpoint and the cap are inconclusive, and the pause comes before the cap.
    @Test func theRuleHoldsForEveryHeadroom() {
        var generator = SeededGenerator(seed: 0x0B21_E7C5)
        for _ in 0..<2_000 {
            let h = Double.random(in: 1.6...16, using: &generator)
            let encoded = CalibrationMath.encodedMergeFactor(headroom: h)
            let linear = CalibrationMath.linearMergeFactor(headroom: h)
            #expect(encoded < CalibrationMath.pauseFactor(headroom: h))
            #expect(CalibrationMath.pauseFactor(headroom: h) < CalibrationMath.sweepCap(headroom: h))
            #expect(CalibrationMath.reading(of: encoded, headroom: h) == .encoded)
            #expect(CalibrationMath.reading(of: linear, headroom: h) == .linearCandidate)
            #expect(CalibrationMath.reading(of: (encoded * linear).squareRoot(), headroom: h) == .inconclusive)
            #expect(CalibrationMath.reading(of: CalibrationMath.sweepCap(headroom: h), headroom: h) == .inconclusive)
            // The confirmation frame clips the merge patch under the encoded truth: nobody can see a difference.
            let frame = CalibrationMath.linearConfirmationFactor(headroom: h)
            #expect(FactorMath.decodeSRGB(CalibrationMath.mergePatch * frame) >= h * 0.999)
        }
    }

    // MARK: Through a session (H 2.667)

    @Test func aMergeNearTheEncodedPredictionRecordsEncoded() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 1.61))
        c.controller.markMerged()
        guard case .swept(let merge?, false) = c.controller.state else {
            Issue.record("expected a merge without the step-3 question, got \(c.controller.state)")
            return
        }
        #expect(abs(merge - 1.62) < 1e-9)
        #expect(c.controller.currentFactor == 1)                       // back to Standard at once
        let record = try #require(c.controller.finish(brighter: true))
        #expect(record.outcome == .encoded)
        #expect(abs((record.mergeFactor ?? 0) - 1.62) < 1e-9)
        #expect(record.osBuild == DisplayFixture.ownerMachine.osBuild && record.mechanism == .table)
        #expect(abs(record.headroomAtTest - h) < 0.01 && record.potentialAtTest == 16)
        #expect(c.controller.state == .finished && c.endings == 1 && c.stateAtEnd == .finished)
    }

    @Test func aMergeNearTheLinearPredictionRecordsLinearOnlyWhenConfirmed() async throws {
        for distinguishable in [true, false] {
            let c = CalibrationRig()
            #expect(await c.ready())
            #expect(await c.sweep(to: 3.0, continuingPastThePause: true))
            c.controller.markMerged()
            guard case .swept(_, true) = c.controller.state else {
                Issue.record("expected the step-3 question, got \(c.controller.state)")
                continue
            }
            c.controller.showLinearConfirmation()
            #expect(c.controller.state == .confirming)
            await c.advance(.seconds(3))
            c.controller.answerLinearConfirmation(distinguishable: distinguishable)
            let record = try #require(c.controller.finish(brighter: true))
            #expect(record.outcome == (distinguishable ? .linear : .inconclusive))
        }
    }

    @Test func aLateMarkIsInconclusive() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 2.2, continuingPastThePause: true))
        c.controller.markMerged()
        #expect(c.controller.state == .swept(mergeFactor: c.factors.dropLast().last, needsConfirmation: false))
        #expect(try #require(c.controller.finish(brighter: true)).outcome == .inconclusive)
    }

    @Test func aSweepThatReachesItsEndIsInconclusive() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(!(await c.sweep(to: 4, continuingPastThePause: true)))  // never reaches ×4: the cap ends it
        #expect(c.controller.state == .swept(mergeFactor: nil, needsConfirmation: false))
        let cap = CalibrationMath.sweepCap(headroom: c.controller.headroom ?? h)
        #expect(c.factors.max() ?? 0 <= cap && c.factors.max() ?? 0 > cap - CalibrationMath.sweepStep)
        let record = try #require(c.controller.finish(brighter: true))
        #expect(record.outcome == .inconclusive && record.mergeFactor == nil)
    }

    @Test func notBrighterIsRecordedForCompatibilityMode() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.showComparison(boosted: true)
        await c.advance(.seconds(2))
        c.controller.showComparison(boosted: false)
        let record = try #require(c.controller.finish(brighter: false))
        #expect(record.outcome == .notBrighter && record.mergeFactor == nil && record.estimatedExponent == nil)
    }

    @Test func nothingMeasuredMeansNoRecord() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(c.controller.finish(brighter: nil) == nil)
        #expect(c.controller.finish(brighter: true) == nil)             // finished: the same (absent) record
    }

    @Test func aColorimeterValueTravelsWithTheRecord() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.setMeasuredSDRWhite(nits: 5)                       // not a plausible SDR white: ignored
        c.controller.setMeasuredSDRWhite(nits: 598)
        let record = try #require(c.controller.finish(brighter: nil))
        #expect(record.measuredSDRWhiteNits == 598 && record.outcome == .inconclusive)
    }
}
