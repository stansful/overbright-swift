// OverbrightBoostTests/Engine/StatusPublicationTests.swift — how often `BoostEngine.status` changes. Every change re-arms
// every observer and invalidates the panel, so events that change nothing visible must publish nothing, while the
// reducer, the interlock and the writer keep using fresh readings (ARCHITECTURE.md §4.5 invariant 1, DESIGN.md §17).
// Counts with the DEBUG `publishCount` probe, never with timing.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct StatusPublicationTests {
    // MARK: E1 — a fresh timestamp alone publishes nothing

    /// Off, the display idle: each screen-parameters event re-reduces with a fresh reading (its time moved), but the
    /// published status does not change, so nothing is republished.
    @Test func unchangedIdleReductionsPublishNothing() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let published = h.engine.publishCount
        let reductions = h.inputs.count
        for _ in 0..<20 {
            await h.advance(.milliseconds(50))
            h.signals.emit(.screenParametersChanged)
            await h.advance(EngineTiming.screenParametersReduceInterval)  // the coalesced reduction (E2)
            // The reducer saw a reading taken now, not the published copy.
            let reading = try #require(h.inputs.last?.displays.first?.feedback.lastReading)
            #expect(reading.time == h.time.now)
        }
        #expect(h.inputs.count - reductions == 20)
        #expect(h.engine.publishCount == published)
        // The published copy is the first reading of this run, not the latest.
        let shown = try #require(h.displayStatus()?.lastReading)
        #expect(shown.time < h.time.now)
    }

    /// A value that moves by 0.0005 or more is published at once; a smaller move is not, though the reducer sees it.
    @Test func aMovedValueRepublishesTheReading() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let idle = try #require(h.displayStatus()?.lastReading?.current)
        h.scripted.setOverride(idle + 0.0002, for: h.builtIn)
        await h.advance(.milliseconds(50))
        var published = h.engine.publishCount
        h.signals.emit(.screenParametersChanged)
        await h.advance(EngineTiming.screenParametersReduceInterval)
        #expect(h.engine.publishCount == published)
        #expect(h.inputs.last?.displays.first?.feedback.lastReading?.current == idle + 0.0002)
        #expect(h.displayStatus()?.lastReading?.current == idle)
        h.scripted.setOverride(idle + 0.25, for: h.builtIn)
        await h.advance(.milliseconds(50))
        published = h.engine.publishCount
        h.signals.emit(.screenParametersChanged)
        await h.advance(EngineTiming.screenParametersReduceInterval)
        let readAt = h.time.now
        // A reading alone is a minor change: published on the trailing edge (E3), once.
        await h.advance(EngineTiming.minorPublishInterval)
        #expect(h.engine.publishCount == published + 1)
        #expect(h.displayStatus()?.lastReading?.current == idle + 0.25)
        #expect(h.displayStatus()?.lastReading?.time == readAt)
    }

    /// Boosted: the drift ticks and headroom checks take fresh readings the interlock uses; nothing is republished
    /// while the headroom holds, and every write stays backed by a fresh reading of the same display.
    @Test func aSteadyBoostPublishesNothingAndEveryWriteStaysBacked() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        let published = h.engine.publishCount
        for _ in 0..<10 {
            h.signals.emit(.screenParametersChanged)
            await h.advance(.milliseconds(500))
        }
        #expect(h.engine.publishCount == published)
        #expect(h.interlockViolations().isEmpty)
        let fresh = try #require(h.controller()?.lastReading)
        #expect(h.time.now - fresh.time < .seconds(2))
    }

    // MARK: E1 — a launch costs nothing

    /// A launch changes nothing the engine holds: no publish and no reduction.
    @Test func aLaunchPublishesAndReducesNothing() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.milliseconds(100))
        let published = h.engine.publishCount
        let reductions = h.inputs.count
        for _ in 0..<5 {
            h.signals.emit(.appLaunched(bundleID: "com.example.editor"))
            await h.advance(.milliseconds(100))
        }
        #expect(h.engine.publishCount == published)
        #expect(h.inputs.count == reductions)
    }

    /// A launched S1 booster still suspends a boosted display: Signals puts it in the snapshot before the event, and
    /// the observed snapshot re-reduces (real Policy).
    @Test func aLaunchedBoosterStillSuspendsABoostedDisplayThroughTheSnapshot() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        await h.start()
        #expect(await h.boost())
        let booster = ConflictingApp(entryID: "booster", severity: .booster, bundleID: "com.example.booster",
                                     processID: 4242, displayName: "Booster")
        h.signals.appLaunched(booster, probe: h.conflicts)
        await h.advance(.milliseconds(500))
        #expect(h.phase() != .boosted)
        #expect(h.everyTableAtBase)
        #expect(h.displayStatus()?.decision?.reasons.contains(.conflict(booster)) == true)
        #expect(h.engine.status.banner != nil)
    }
}
