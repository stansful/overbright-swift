// OverbrightBoostTests/Engine/ScreenParametersReduceTests.swift — screen-parameters notifications (one per frame while
// headroom moves, up to 122/s): the headroom check and its safety drop stay synchronous in the event handler (D5,
// ARCHITECTURE.md §4.3), the re-reduction they ask for runs at most once per `screenParametersReduceInterval` on the
// trailing edge, and any other reduction runs at once. Reductions are counted from the reducer's inputs.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct ScreenParametersReduceTests {
    private func boosted() async -> EngineHarness {
        let h = EngineHarness()
        h.setPreferences { $0.capMode = .peak }
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))                                      // ramp, settle and the recovery burst done
        return h
    }

    /// H drops below 0.98 × applied: the table is lowered to 0.97 × H when `emit` returns, before time moves; the
    /// re-reduction waits for the slot.
    @Test func theSafetyDropLandsBeforeEmitReturns() async throws {
        let h = await boosted()
        let reductions = h.inputs.count
        let applied = try #require(h.displayStatus()?.appliedGain)
        let dropped = applied / 0.98 - 0.05
        h.scripted.setGrant(dropped, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        let factor = try #require(h.liveFactor())
        let written = FactorMath.lightGain(forTableFactor: factor, domain: .encoded)
        #expect(written <= FactorMath.headroomMargin * dropped + 1e-5)
        #expect(h.interlockViolations().isEmpty)
        // The drop asked for its own reduction (a controller change), which is never coalesced.
        await h.settle()
        #expect(h.inputs.count == reductions + 1)
        #expect(!h.engine.activeTaskNames.contains("screenParameters"))
    }

    /// 100 notifications in 1 s while boosted: every one runs the headroom check (a fresh reading when `emit`
    /// returns), the reducer runs at most 11 times, and the last one lands within the interval after the burst.
    @Test func aBurstReducesAtMostTenTimesASecond() async throws {
        let h = await boosted()
        let reductions = h.inputs.count
        var checks = 0
        for _ in 0..<100 {
            h.signals.emit(.screenParametersChanged)
            if h.controller()?.lastReading?.time == h.time.now { checks += 1 }
            await h.advance(.milliseconds(10))
        }
        #expect(checks == 100)
        let during = h.inputs.count - reductions
        #expect(during >= 9 && during <= 11, "\(during) reductions")
        await h.advance(EngineTiming.screenParametersReduceInterval)
        #expect(h.inputs.count - reductions <= 11)
        #expect(!h.engine.activeTaskNames.contains("screenParameters"))
        #expect(h.phase() == .boosted)
    }

    /// Off: the same burst costs at most 11 reductions, and the slot is empty once it has fired (§4.5 invariant 4).
    @Test func offABurstReducesAtMostTenTimesASecondAndLeavesNoTask() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let reductions = h.inputs.count
        for _ in 0..<100 {
            h.signals.emit(.screenParametersChanged)
            await h.advance(.milliseconds(10))
        }
        #expect(h.inputs.count - reductions <= 11)
        await h.advance(.milliseconds(200))
        #expect(h.engine.activeTaskCount == 0)
        #expect(h.time.sleeperCount == 0)
    }

    /// The potential follows within the interval: a verdict that depends on it is reduced ≤ 100 ms after the
    /// notification.
    @Test func theTrailingReductionSeesTheLatestReading() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let reductions = h.inputs.count
        h.signals.emit(.screenParametersChanged)
        await h.settle()
        #expect(h.inputs.count == reductions)
        #expect(h.engine.activeTaskNames.contains("screenParameters"))
        h.scripted.update(h.builtIn) { $0.potential = 4 }
        await h.advance(EngineTiming.screenParametersReduceInterval)
        #expect(h.inputs.count == reductions + 1)
        #expect(h.inputs.last?.displays.first?.feedback.lastReading?.potential == 4)
    }

    /// Any other event (or request) reduces at once and takes the waiting reduction with it.
    @Test func anotherEventReducesAtOnceAndCancelsTheSlot() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let reductions = h.inputs.count
        h.signals.emit(.screenParametersChanged)
        await h.settle()
        #expect(h.engine.activeTaskNames.contains("screenParameters"))
        h.signals.emit(.appActivated(bundleID: "com.example.editor"))
        await h.settle()
        #expect(h.inputs.count == reductions + 1)
        #expect(!h.engine.activeTaskNames.contains("screenParameters"))
        await h.advance(.milliseconds(200))
        #expect(h.inputs.count == reductions + 1)
        h.signals.emit(.screenParametersChanged)
        h.engine.setOn(true, source: .panel)
        #expect(h.inputs.count == reductions + 2)
        #expect(!h.engine.activeTaskNames.contains("screenParameters"))
    }

    /// Stopping the engine drops a waiting reduction.
    @Test func stopDropsTheWaitingReduction() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        h.signals.emit(.screenParametersChanged)
        h.engine.stopNow()
        #expect(h.engine.activeTaskCount == 0)
        let reductions = h.inputs.count
        await h.advance(.milliseconds(200))
        #expect(h.inputs.count == reductions)
    }
}
