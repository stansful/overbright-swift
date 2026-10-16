// OverbrightBoostTests/Engine/RampTests.swift — ramps (ARCHITECTURE.md §5.7, D5; DESIGN.md §3.3): at least 6 steps,
// smoothstep in stops, the last step exactly at the target, and the right durations in the running engine (300 ms,
// 160 ms under Reduce Motion, 120 ms for Back to Standard).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct RampTests {
    @Test func stepCountsAndDurations() {
        #expect(RampPlanner.duration(.standard) == .milliseconds(300))
        #expect(RampPlanner.duration(.reduceMotion) == .milliseconds(160))
        #expect(RampPlanner.duration(.backToStandard) == .milliseconds(120))
        #expect(RampPlanner.stepCount(for: .milliseconds(300)) == 18)
        #expect(RampPlanner.stepCount(for: .milliseconds(160)) == 10)
        #expect(RampPlanner.stepCount(for: .milliseconds(120)) == 7)
        #expect(RampPlanner.stepCount(for: .milliseconds(20)) == EngineTiming.minimumRampSteps)
        for kind in [RampPlanner.Kind.standard, .reduceMotion, .backToStandard] {
            let plan = RampPlanner.plan(from: 1, to: 1.6, kind: kind)
            #expect(plan.gains.count >= 6)
            let total = plan.interval * plan.gains.count
            #expect(abs((total - RampPlanner.duration(kind)).timeInterval) < 1e-9)
        }
    }

    @Test func gainsEaseInStopsAndEndExactly() {
        for (from, to) in [(1.0, 1.667), (2.587, 1.0), (1.0, 0.02), (0.5, 1.3)] {
            let gains = RampPlanner.gains(from: from, to: to, steps: 18)
            #expect(gains.count == 18)
            #expect(gains.last == to)
            let increasing = to > from
            #expect(zip(gains, gains.dropFirst()).allSatisfy { increasing ? $1 >= $0 : $1 <= $0 })
            // Smoothstep in log₂ space: half the steps cover half the stops.
            let middle = log2(gains[8]), expected = (log2(from) + log2(to)) / 2
            #expect(abs(middle - expected) < 1e-9)
            // Gentle at both ends: the first and last steps are the smallest.
            let deltas = zip(gains, gains.dropFirst()).map { abs(log2($1) - log2($0)) }
            #expect(deltas.first ?? 0 < deltas[8] && deltas.last ?? 0 < deltas[8])
        }
        #expect(RampPlanner.smoothstep(-1) == 0 && RampPlanner.smoothstep(2) == 1 && RampPlanner.smoothstep(0.5) == 0.5)
    }

    /// The ramp in the engine: one write per step, the last exactly one ramp duration after the first request.
    @Test(arguments: [(false, 300), (true, 160)])
    func engineRampDuration(reduceMotion: Bool, milliseconds: Int) async throws {
        let h = EngineHarness()
        h.signals.snapshot.reduceMotion = reduceMotion
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        let start = h.time.now
        let before = h.writes().count
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(milliseconds + 20), step: .milliseconds(1))
        let ramp = Array(h.writes().dropFirst(before))
        #expect(ramp.count == RampPlanner.stepCount(for: .milliseconds(milliseconds)))
        let last = try #require(ramp.last)
        #expect(abs((last.time - start).timeInterval - Double(milliseconds) / 1000) < 0.002)
        #expect(h.phase() == .boosted)
    }

    /// Back to Standard ramps over 120 ms in at least 6 steps and ends on the baseline.
    @Test func backToStandardTakes120Milliseconds() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        let start = h.time.now
        let before = h.writes().count
        h.engine.returnToStandard(source: .menu)
        await h.advance(.milliseconds(140), step: .milliseconds(1))
        let ramp = Array(h.writes().dropFirst(before))
        #expect(ramp.count == 7)
        let last = try #require(ramp.last)
        #expect(abs((last.time - start).timeInterval - 0.120) < 0.002)
        #expect(h.everyTableAtBase && h.phase() == .idle)
    }
}
