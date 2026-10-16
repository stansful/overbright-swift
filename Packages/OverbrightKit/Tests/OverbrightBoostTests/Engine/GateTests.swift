// OverbrightBoostTests/Engine/GateTests.swift — the gate rules of D6 (ARCHITECTURE.md §4.3, §4.4): movement, the
// ready thresholds of both paths, stability over 1.5 s, the rung and gate timeouts, and the pre-held test.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite struct GateTests {
    private func at(_ milliseconds: Int) -> MonotonicInstant { MonotonicInstant(sinceOrigin: .milliseconds(milliseconds)) }

    /// Samples every 100 ms from `start` with the given headroom values.
    private func samples(from start: Int, _ values: [Double]) -> [GateEvaluator.Sample] {
        values.enumerated().map { GateEvaluator.Sample(time: at(start + 100 * $0.offset), headroom: $0.element) }
    }

    @Test func movementIsFiveHundredthsAboveIdle() {
        #expect(!GateEvaluator.isMovement(1.249, idle: 1.2))
        #expect(GateEvaluator.isMovement(1.25, idle: 1.2))
        #expect(GateEvaluator.isMovement(1.05, idle: 1.0))
    }

    @Test func readyThresholdsPerPath() {
        #expect(GateEvaluator.readyThreshold(path: .normal, idle: 1.0) == 1.1)
        #expect(abs(GateEvaluator.readyThreshold(path: .normal, idle: 1.2) - 1.3) < 1e-12)   // macOS 27 idles at ≈ 1.2
        #expect(GateEvaluator.readyThreshold(path: .preHeld, idle: 2.6) == 1.1)
    }

    @Test func stabilityNeedsTheWholeWindow() {
        let steady = samples(from: 0, Array(repeating: 2.6, count: 16))          // 0 … 1.5 s
        #expect(GateEvaluator.isStable(steady, now: at(1_500)))
        #expect(!GateEvaluator.isStable(Array(steady.prefix(15)), now: at(1_400)))
        var wobble = steady
        wobble[10].headroom = 2.71                                                // a range above 0.1
        #expect(!GateEvaluator.isStable(wobble, now: at(1_500)))
        let withinBand = samples(from: 0, (0..<16).map { 2.6 + ($0.isMultiple(of: 2) ? 0.04 : -0.04) })
        #expect(GateEvaluator.isStable(withinBand, now: at(1_500)))
        #expect(!GateEvaluator.isStable([], now: at(1_500)))
    }

    @Test func normalPathMovesThenReadies() {
        let idle = 1.0
        let flat = samples(from: 300, [1, 1, 1])
        #expect(GateEvaluator.evaluate(path: .normal, samples: flat, idle: idle, presentedAt: at(200), movedAt: nil,
                                       now: at(500)) == .waiting)
        let rising = flat + samples(from: 600, [1.2])
        #expect(GateEvaluator.evaluate(path: .normal, samples: rising, idle: idle, presentedAt: at(200), movedAt: nil,
                                       now: at(600)) == .moved)
        let held = rising + samples(from: 700, Array(repeating: 2.667, count: 16))
        #expect(GateEvaluator.evaluate(path: .normal, samples: held, idle: idle, presentedAt: at(200), movedAt: at(600),
                                       now: at(2_100)) == .waiting)
        let longer = held + samples(from: 2_300, [2.667])
        #expect(GateEvaluator.evaluate(path: .normal, samples: longer, idle: idle, presentedAt: at(200),
                                       movedAt: at(600), now: at(2_300)) == .ready(headroom: 2.667))
    }

    @Test func normalPathNeedsMoreThanIdlePlusATenth() {
        // macOS 27 idles at 1.2: a stable 1.25 is movement but not ready (needs 1.3).
        let steady = samples(from: 0, Array(repeating: 1.25, count: 20))
        #expect(GateEvaluator.evaluate(path: .normal, samples: steady, idle: 1.2, presentedAt: at(0), movedAt: at(0),
                                       now: at(1_900)) == .waiting)
    }

    @Test func rungTimesOutWithoutMovement() {
        let flat = samples(from: 300, Array(repeating: 1.0, count: 25))
        #expect(GateEvaluator.evaluate(path: .normal, samples: flat, idle: 1, presentedAt: at(200), movedAt: nil,
                                       now: at(2_600)) == .waiting)
        #expect(GateEvaluator.evaluate(path: .normal, samples: flat, idle: 1, presentedAt: at(200), movedAt: nil,
                                       now: at(2_700)) == .rungTimedOut)
    }

    @Test func gateTimesOutTwelveSecondsAfterMovement() {
        let climbing = samples(from: 0, (0..<130).map { 1.0 + 0.012 * Double($0) })   // never stable
        #expect(GateEvaluator.evaluate(path: .normal, samples: climbing, idle: 1, presentedAt: at(0), movedAt: at(500),
                                       now: at(12_400)) == .waiting)
        #expect(GateEvaluator.evaluate(path: .normal, samples: climbing, idle: 1, presentedAt: at(0), movedAt: at(500),
                                       now: at(12_500)) == .gateTimedOut)
    }

    @Test func preHeldPathSkipsMovement() {
        let held = samples(from: 0, Array(repeating: 2.6, count: 16))
        #expect(GateEvaluator.evaluate(path: .preHeld, samples: held, idle: 2.6, presentedAt: at(0), movedAt: at(0),
                                       now: at(1_500)) == .ready(headroom: 2.6))
        let low = samples(from: 0, Array(repeating: 1.08, count: 16))
        #expect(GateEvaluator.evaluate(path: .preHeld, samples: low, idle: 1.08, presentedAt: at(0), movedAt: at(0),
                                       now: at(1_500)) == .waiting)
        #expect(GateEvaluator.evaluate(path: .preHeld, samples: low, idle: 1.08, presentedAt: at(0), movedAt: at(0),
                                       now: at(12_000)) == .gateTimedOut)
    }

    @Test func preHeldRule() {
        #expect(GateEvaluator.isPreHeld(idleReads: [1, 1, 1], gain: 1.29, ownSurface: true))
        #expect(GateEvaluator.isPreHeld(idleReads: [2.6, 2.59, 2.6], gain: 1.29, ownSurface: false))
        #expect(!GateEvaluator.isPreHeld(idleReads: [1.2, 1.21, 1.2], gain: 1.29, ownSurface: false))
        // H0 ≥ 1.3 but below G ÷ 0.97 (1.718): pre-held only through the stable ≥ 1.25 rule.
        #expect(GateEvaluator.isPreHeld(idleReads: [1.3, 1.29, 1.3], gain: 1.667, ownSurface: false))
        #expect(!GateEvaluator.isPreHeld(idleReads: [1.1, 1.2, 1.3], gain: 1.667, ownSurface: false))
        #expect(GateEvaluator.isPreHeld(idleReads: [1.26, 1.25, 1.26], gain: 1.1, ownSurface: false))
        #expect(!GateEvaluator.isPreHeld(idleReads: [], gain: 1.1, ownSurface: false))
    }
}
