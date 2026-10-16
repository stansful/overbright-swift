// OverbrightBoostTests/SelfTest/HeadroomTraceTests.swift — the pure judgement behind the self-test's verdicts and the
// calibration's arm (ARCHITECTURE.md §4.4 gate thresholds, D6; §8.4) and the ladder they walk (§4.7).
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite nonisolated struct HeadroomTraceTests {
    /// Samples every 0.1 s from `from` to `to` (inclusive), H given by `h`.
    private func trace(baseline: [Double] = [1, 1, 1], from: Double = 0.1, to: Double,
                       _ h: (Double) -> Double) -> HeadroomTrace {
        var trace = HeadroomTrace(baselineReads: baseline)
        var t = from
        while t <= to + 1e-9 {
            trace.append(seconds: t, headroom: h(t))
            t = (t * 10 + 1).rounded() / 10
        }
        return trace
    }

    @Test func preHeldFollowsD6() {
        #expect(HeadroomTrace(baselineReads: [1.31, 1.2, 1.25]).isPreHeld)          // ≥ 1.3
        #expect(HeadroomTrace(baselineReads: [1.26, 1.27, 1.25]).isPreHeld)         // ≥ 1.25 and stable
        #expect(!HeadroomTrace(baselineReads: [1.26, 1.1, 1.0]).isPreHeld)          // ≥ 1.25 but moving
        #expect(!HeadroomTrace(baselineReads: [1.2, 1.2, 1.2]).isPreHeld)           // macOS 27's idle 1.2
    }

    @Test func thresholdsFollowTheGate() {
        let idle = HeadroomTrace(baselineReads: [1, 1, 1])
        #expect(idle.movementThreshold == 1.05 && idle.readyThreshold == 1.1)
        let raised = HeadroomTrace(baselineReads: [1.2, 1.18, 1.2])
        #expect(abs(raised.readyThreshold - 1.3) < 1e-12)
        #expect(HeadroomTrace(baselineReads: [2.6]).readyThreshold == EngineTiming.readyMinimum)
    }

    @Test func aRampThatSettlesIsHeldWithItsTimes() throws {
        let t = trace(to: 6) { s in min(1 + max(s - 0.2, 0) * 1.667, 2.667) }
        #expect(t.verdict == .held && t.heldFraction == 1)
        let movement = try #require(t.firstMovement), stable = try #require(t.firstStable)
        #expect(abs(movement - 0.3) < 1e-9)
        #expect(abs(stable - 2.7) < 1e-9)                                            // ramp ends 1.2 s, + 1.5 s
    }

    @Test func stabilityNeedsAFullWindowInTheBand() {
        #expect(trace(to: 1.5) { _ in 2 }.firstStable == nil)                        // 1.4 s of samples only
        #expect(trace(to: 1.6) { _ in 2 }.firstStable != nil)
        let wobble = trace(to: 6) { s in 2 + (Int((s * 10).rounded()) % 2 == 0 ? 0.06 : -0.06) }
        #expect(wobble.firstStable == nil && wobble.verdict == .engagedButDropped)
    }

    @Test func verdicts() {
        #expect(trace(to: 5) { _ in 1.02 }.verdict == .noEngage)
        #expect(trace(to: 5) { s in s < 3 ? 2 : 1 }.verdict == .engagedButDropped)   // stable at 1.6 s, lost at 3
        #expect(trace(to: 5) { s in s < 4.9 ? 2 : 1.9 }.verdict == .held)            // a dip inside the band
        #expect(trace(baseline: [2.6, 2.6, 2.6], to: 5) { _ in 2.6 }.verdict == .invalidBaseline)
    }

    // MARK: The ladder

    private let tahoe = DisplayFixture.ownerMachine
    private let sonoma = MachineIdentity(model: "Mac16,5", osBuild: "23A344", osMajor: 14, osMinor: 0, osPatch: 0)

    @Test func theDefaultLadderFollowsSection4_7() {
        let rungs = MeasurementLadder.rungs(everyStrategy: false, machine: tahoe, headroomTag: 16)
        #expect(rungs.map(\.request.strategy) == [.taggedLayer, .taggedLayer, .metalOneShot, .metalOneShot,
                                                  .metalKeepAlive, .hlgStill, .hlgStill])
        #expect(rungs.map(\.request.pixel) == [.black, .bright, .black, .bright, .bright, .black, .bright])
        #expect(rungs.allSatisfy { $0.isAvailable })
        let old = MeasurementLadder.rungs(everyStrategy: false, machine: sonoma, headroomTag: 16)
        #expect(old.first?.request.strategy == .metalOneShot && old.count == 5)
    }

    @Test func everyMethodAddsTheInMemoryHLGFrameAndListsT1() {
        let rungs = MeasurementLadder.rungs(everyStrategy: true, machine: sonoma, headroomTag: 4.6549)
        #expect(rungs.count == 8 && rungs.contains { $0.request.strategy == .hlgSampleBuffer })
        #expect(rungs.filter { !$0.isAvailable }.map(\.request.strategy) == [.taggedLayer, .taggedLayer])
    }

    @Test func requestsSitInTheCornerWithTheTagPolicy() {
        let rungs = MeasurementLadder.rungs(everyStrategy: true, machine: tahoe, headroomTag: 1)
        #expect(rungs.allSatisfy { $0.request.placement == .topRightCorner && $0.request.edgePoints == 1 })
        #expect(rungs.allSatisfy { $0.request.headroomTag == 1.01 })                // T1 clamps at 1.01
        #expect(rungs.allSatisfy { $0.request.blend == ($0.request.pixel == .black ? .normal : .softLight) })
        #expect(MeasurementLadder.rungs(everyStrategy: false, machine: tahoe, headroomTag: 16)
            .allSatisfy { $0.request.headroomTag == 16 })
    }
}
