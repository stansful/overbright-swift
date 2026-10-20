// OverbrightBoostTests/Engine/BoostSourcesTests.swift — Signals' boost-only sources (the full-screen watch, battery
// percent, OLED idle, the schedule sleep) follow boosting, not dimming (D30, ARCHITECTURE.md §7.1): every guard they
// feed applies to the boost half only (D10). A dimmed-only display keeps its drift check and the hang watchdog (the
// ledger holds it); dim → boost reads the power source synchronously before any boost write.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct BoostSourcesTests {
    /// Dimmed only: the sources never start, while the drift check runs and the ledger (hence the hang watchdog)
    /// holds the display.
    @Test func aDimmedOnlyDisplayRunsNoBoostSources() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setDimLight(0.5, for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        await h.advance(.seconds(5))
        #expect(!h.signals.boostActiveCalls.contains(true))
        #expect(!h.engine.boostSourcesActive)
        #expect(h.engine.activeTaskNames.contains("\(h.builtIn.rawValue).drift"))
        #expect(h.engine.ledger.isMarked(h.builtIn))
        #expect(h.engine.settings[EngineRecords.boostMarker]?.displays == [h.builtIn])
    }

    /// Boosted → dimmed: the sources run while the boost is on screen and stop once the display only dims.
    @Test func boostToDimStopsTheSourcesOnceOnlyDimming() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        #expect(h.signals.boostActiveCalls.last == true)
        h.engine.setDimLight(0.5, for: h.builtIn, source: .panel)
        #expect(h.engine.boostSourcesActive)                              // the ramp starts from the boost
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        await h.advance(.milliseconds(100))
        #expect(h.signals.boostActiveCalls.last == false)
        #expect(h.engine.activeTaskNames.contains("\(h.builtIn.rawValue).drift"))
    }

    /// Dim → boost: arming starts the sources (their synchronous power read) in the same turn as the request, before
    /// any write above the baseline.
    @Test func dimToBoostReadsThePowerSourceBeforeTheFirstBoostWrite() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setDimLight(0.5, for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        let refreshes = h.signals.refreshPowerNowCount
        let writes = h.writes().count
        h.engine.setLevel(LevelPreset.brightRoom.position, for: h.builtIn, source: .panel)
        #expect(h.signals.refreshPowerNowCount > refreshes)
        #expect(h.signals.boostActiveCalls.last == true)
        #expect(h.writes().count == writes)                               // nothing written yet
        let requested = h.time.now
        #expect(await h.boost())
        let base = try #require(h.base())
        let firstBoost = try #require(h.writes().first { write in
            (EngineHarness.factor(of: write.table, over: base) ?? 1) > 1 + 1e-6
        })
        #expect(firstBoost.time > requested)
    }

    /// The read matters: while only dimming no battery source keeps the snapshot current, and the synchronous read
    /// before the boost sees the battery below the guard, so the boost never starts (real Policy).
    @Test func dimToBoostSeesTheBatteryOfNow() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)                // the battery guard's default: below 20 %
        await h.start()
        h.engine.setDimLight(0.5, for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        h.signals.powerOnRefresh = PowerState(source: .battery, batteryPercent: 10, isLowPowerMode: false)
        h.engine.setLevel(LevelPreset.brightRoom.position, for: h.builtIn, source: .panel)
        await h.advance(.seconds(5))
        #expect(h.phase() != .boosted)
        let base = try #require(h.base())
        #expect(!h.writes().contains { (EngineHarness.factor(of: $0.table, over: base) ?? 1) > 1 + 1e-6 })
        #expect(h.displayStatus()?.decision?.reasons.contains { if case .battery = $0 { true } else { false } } == true)
    }
}
