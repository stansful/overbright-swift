// OverbrightBoostTests/Calibration/CalibrationSafetyTests.swift — what keeps the calibration safe (ARCHITECTURE.md §5.2,
// §5.8, §10.7; DESIGN.md §9): Standard first, the sweep's steps, its pause at 1.15 × the encoded prediction and its cap,
// the black surround, the comparison's flip limit, the linear confirmation required before `.linear`, and a record that
// no longer counts once the OS build, mechanism or potential changed.
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct CalibrationSafetyTests {
    private let h = 1600.0 / 600

    @Test func startingReturnsTheDisplayToStandardBeforeAnything() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(c.driver.calls.first == .returnToStandard)
        #expect(c.driver.calls.dropFirst().first == .arm(.taggedLayer, .black))   // the cheapest rung
        #expect(c.controller.currentFactor == 1 && c.factors.isEmpty)
        #expect(abs((c.controller.headroom ?? 0) - h) < 0.01)
    }

    /// The pattern the window draws (`CalibrationPattern.standard`) is DESIGN.md §9's, and the predictions are about its
    /// merge patch, the third one, next to white (C-BOOST-21).
    @Test func theWindowDrawsFourPatchesOnBlack() {
        let pattern = CalibrationPattern.standard
        #expect(pattern.patches == [0.85, 0.90, 0.95, 1.00] && pattern.surround == 0)
        #expect(pattern.patches.firstIndex(of: pattern.mergePatch) == pattern.patches.count - 2)
        #expect(pattern.patches.last == 1 && pattern.patches == pattern.patches.sorted())
        #expect(CalibrationMath.mergePatch == pattern.mergePatch)
        #expect(abs(CalibrationMath.encodedMergeFactor(headroom: h) - 1.613) < 0.001)   // §5.6: 1.61 at H 2.667
        #expect(abs(CalibrationMath.linearMergeFactor(headroom: h) - 2.997) < 0.001)    // and 3.00
    }

    @Test func theSweepStepsTwoHundredthsEveryFourHundredMilliseconds() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.startSweep()
        #expect(c.controller.state == .sweeping && c.controller.currentFactor == 1)
        await c.advance(.milliseconds(400))
        #expect(abs(c.controller.currentFactor - 1.02) < 1e-9)
        await c.advance(.milliseconds(1200))
        #expect(abs(c.controller.currentFactor - 1.08) < 1e-9)
        let cap = CalibrationMath.sweepCap(headroom: h)
        #expect(c.driver.calls.allSatisfy { call in
            if case .factor(_, let maxFactor) = call { abs(maxFactor - cap) < 0.01 } else { true }
        })
    }

    @Test func theSweepPausesAtTheEncodedLimitAndHoldsUntilKeepGoing() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.startSweep()
        #expect(await c.advance(until: { c.controller.isSweepPausedAtLimit }, limit: .seconds(30)))
        let pauseAt = CalibrationMath.pauseFactor(headroom: h)
        let held = c.controller.currentFactor
        #expect(held <= pauseAt && held > pauseAt - CalibrationMath.sweepStep)
        let writes = c.factors.count
        await c.advance(.seconds(5))
        #expect(c.controller.currentFactor == held && c.factors.count == writes)  // holds, writes nothing
        c.controller.continueSweep()
        #expect(!c.controller.isSweepPausedAtLimit)
        await c.advance(.milliseconds(400))
        #expect(c.controller.currentFactor > pauseAt)
        #expect(c.codes.contains("calibration.paused") && c.codes.contains("calibration.continued"))
    }

    @Test func theSweepNeverPassesItsCap() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        _ = await c.sweep(to: 10, continuingPastThePause: true)
        let cap = CalibrationMath.sweepCap(headroom: h)
        #expect(!c.factors.isEmpty && c.factors.allSatisfy { $0 <= cap })
        #expect(c.controller.currentFactor == 1)
    }

    @Test func comparisonsFlipAtMostOncePerOneAndAHalfSeconds() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        let boosted = CalibrationMath.comparisonFactor(headroom: h)
        c.controller.showComparison(boosted: true)
        #expect(c.controller.currentFactor == boosted)                 // the first flip is immediate
        await c.advance(.milliseconds(500))
        c.controller.showComparison(boosted: false)
        c.controller.showComparison(boosted: true)
        c.controller.showComparison(boosted: false)                    // the latest request wins
        await c.advance(.milliseconds(800))
        #expect(c.controller.currentFactor == boosted)                 // 1.3 s since the flip: still waiting
        await c.advance(.milliseconds(300))
        #expect(c.controller.currentFactor == 1)
        #expect(c.factors == [boosted, 1])
        await c.advance(.seconds(3))
        #expect(c.factors == [boosted, 1])
    }

    @Test func theComparisonIsTheSafeEncodedFactorCappedByHeadroom() async {
        let c = CalibrationRig()
        c.rig.headroom.update(c.key) { $0.grant = 1.2 }
        #expect(await c.ready())
        c.controller.showComparison(boosted: true)
        #expect(abs(c.controller.currentFactor - pow(0.97 * 1.2, 1 / 2.4)) < 1e-6)
    }

    // MARK: Linear only with the confirmation

    @Test func linearIsNeverRecordedWithoutTheConfirmationFrame() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 3.0, continuingPastThePause: true))
        c.controller.markMerged()
        c.controller.answerLinearConfirmation(distinguishable: true)  // no frame shown: ignored
        #expect(c.codes.contains("calibration.answerWithoutFrame"))
        #expect(try #require(c.controller.finish(brighter: true)).outcome == .inconclusive)
    }

    @Test func theConfirmationFrameIsZeroPointNineSevenHForTwoSeconds() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 3.0, continuingPastThePause: true))
        c.controller.markMerged()
        c.controller.showLinearConfirmation()
        let frame = CalibrationMath.linearConfirmationFactor(headroom: h)
        #expect(abs(c.controller.currentFactor - frame) < 0.01)
        await c.advance(.milliseconds(1900))
        #expect(c.controller.state == .confirming && c.controller.currentFactor > 2)
        await c.advance(.milliseconds(200))
        #expect(c.controller.currentFactor == 1)
        guard case .swept(_, true) = c.controller.state else {
            Issue.record("expected the question again, got \(c.controller.state)")
            return
        }
    }

    @Test func noConfirmationIsOfferedAfterAnEncodedMerge() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 1.6))
        c.controller.markMerged()
        let writes = c.factors.count
        c.controller.showLinearConfirmation()
        c.controller.answerLinearConfirmation(distinguishable: true)
        #expect(c.factors.count == writes && c.controller.currentFactor == 1)
        #expect(try #require(c.controller.finish(brighter: true)).outcome == .encoded)
    }

    // MARK: Validity

    @Test func aRecordStopsCountingWhenTheBuildMechanismOrPotentialChanges() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 3.0, continuingPastThePause: true))
        c.controller.markMerged()
        c.controller.showLinearConfirmation()
        await c.advance(.seconds(2))
        c.controller.answerLinearConfirmation(distinguishable: true)
        let record = try #require(c.controller.finish(brighter: true))
        #expect(record.outcome == .linear)
        let machine = DisplayFixture.ownerMachine
        func domain(_ machine: MachineIdentity, mechanism: Mechanism = .table, potential: Double = 16)
            -> TransferDomain {
            TransferDomainResolver.effectiveDomain(record, mechanism: mechanism, machine: machine, potential: potential)
        }
        #expect(domain(machine) == .linear)
        #expect(domain(machine, potential: 16 * 1.04) == .linear)
        var updated = machine
        updated.osBuild = "26B100"
        #expect(domain(updated) == .encoded)                           // macOS changed
        #expect(domain(machine, mechanism: .overlay) == .encoded)      // the other mechanism
        #expect(domain(machine, potential: 16 * 1.06) == .encoded)     // the preset changed
    }

    @Test func aCompatibilityModeSessionRecordsTheOverlay() async throws {
        let c = CalibrationRig()
        c.controller.mechanism = .overlay
        #expect(await c.ready())
        #expect(await c.sweep(to: 1.6))
        c.controller.markMerged()
        #expect(try #require(c.controller.finish(brighter: true)).mechanism == .overlay)
    }
}
