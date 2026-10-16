// OverbrightBoostTests/Engine/RebaseTests.swift — the event-driven re-base (ARCHITECTURE.md §4.8): on a reconfiguration,
// ColorSync or accessibility event the expected base is recomputed, the engine waits (≤ 1 s) for WindowServer's new
// table, adopts it after two identical reads (or the new profile base when WindowServer kept our table), updates the
// ledger in the same step and reapplies the target with a ramp — boosted, dimmed, suspended, gating and disarming alike
// (§4.3: "whether or not the display is scaled").
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct RebaseTests {
    private let base = GammaTable.identity(count: 1024)
    /// An HDR toggle or preset change gives the display a new base (per-channel white point).
    private let newBase: GammaTable = {
        func channel(_ scale: Double) -> [Float] { (0..<1024).map { Float(scale * Double($0) / 1023) } }
        return GammaTable(red: channel(0.94), green: channel(0.97), blue: channel(0.91))
    }()

    private func expectRebased(_ h: EngineHarness, gain: Double) throws {
        #expect(h.controller()?.baseline == newBase)
        #expect(h.engine.ledger.entries().first?.baseline == newBase)
        let factor = try #require(h.controller()?.appliedFactor)
        #expect(abs(factor - FactorMath.tableFactor(forLightGain: gain, domain: .encoded)) < 1e-9)
        #expect(h.table()?.matches(newBase.scaled(by: factor), tolerance: 1e-6) == true)
        #expect(h.codes.contains("baseline.adopted") && h.codes.contains("drift.reapplied"))
    }

    private func lock(_ h: EngineHarness) {
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
    }

    private func unlock(_ h: EngineHarness) {
        h.signals.snapshot.isScreenLocked = false
        h.signals.emit(.unlocked)
    }

    @Test func rebaseWhileBoosted() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        await h.advance(.milliseconds(800))
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
        #expect(h.phase() == .boosted)
        // The watchdog's baseline (the ledger) is the new base, not the old curve.
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase)
    }

    @Test func rebaseWhileDimmed() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.milliseconds(800))
        try expectRebased(h, gain: LevelMapping.dimLight(for: LevelPosition(-0.5)))
        #expect(h.phase() == .dimmed)
    }

    /// The event arrives before WindowServer applies the new table: the engine waits for a read that differs from
    /// its last write (at most 1 s), then adopts.
    @Test func waitsForWindowServersTable() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.accessibilityDisplayOptionsChanged)
        await h.advance(.milliseconds(300))
        h.gamma.resetToBase(1)                                            // WindowServer applies it now
        await h.advance(.milliseconds(800))
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
    }

    /// WindowServer kept our table: after 1 s the new profile base is adopted anyway.
    @Test func adoptsTheProfileBaseWhenOurTableWasKept() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.milliseconds(1_700))
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
    }

    /// Another booster's table (a uniform multiple of the old baseline) is never adopted as the new base.
    @Test func neverAdoptsAMultipleOfTheBaseline() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.foreignWrite(base.scaled(by: 1.3), to: 1)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.milliseconds(1_500))
        #expect(h.controller()?.baseline == base)
        #expect(!h.codes.contains("baseline.adopted"))
    }

    /// A profile change while locked (suspended, the table at its baseline): the new base is adopted then, so the
    /// re-gate after unlock multiplies it and "off" restores it, not the previous profile's curve.
    @Test func rebaseWhileSuspended() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        lock(h)
        #expect(h.phase() == .suspended(.shielded))
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        h.signals.emit(.colorProfileChanged)                              // a second event in the same pass
        await h.advance(.milliseconds(500))
        #expect(h.controller()?.baseline == newBase && h.phase() == .suspended(.shielded))
        unlock(h)
        #expect(await h.boost())
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase && h.engine.ledger.entries().isEmpty)
    }

    /// WindowServer keeps our baseline write over the lock: after 1 s the new profile base is adopted and written.
    @Test func suspendedDisplayKeepingOurTableGetsTheNewBase() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        lock(h)
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.milliseconds(1_500))
        #expect(h.controller()?.baseline == newBase && h.table() == newBase)
        #expect(h.phase() == .suspended(.shielded))
    }

    /// A base change while arming or gating: the gate's ramp multiplies the new base.
    @Test func rebaseWhileGating() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(450))
        #expect(h.controller()?.isPreparing == true)
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.accessibilityDisplayOptionsChanged)
        #expect(await h.boost())
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase)
    }

    /// The base changes while the disarm ramp runs: the ramp ends on the old curve, and reaching idle replaces it.
    @Test func baseChangeDuringTheDisarmEndsOnTheNewBase() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.engine.setOn(false, source: .panel)
        await h.advance(.milliseconds(50))
        #expect(h.phase() == .disarming)
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.phase() == .idle && h.table() == newBase)
        #expect(h.engine.activeTaskCount == 0 && h.liveTriggers().isEmpty)
    }

    /// A lock right after the event cuts the re-base short (its baseline write is the old curve): the event stays
    /// pending and the re-gate after unlock adopts the new base.
    @Test func aShieldDuringTheRebaseKeepsItPending() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        lock(h)
        #expect(h.controller()?.pendingRebase != nil)
        await h.advance(.seconds(2))
        unlock(h)
        #expect(await h.boost())
        await h.advance(.seconds(2))
        try expectRebased(h, gain: pow(ReferenceReducer.defaultTop, 0.5))
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase)
    }

    /// An idle display has nothing to re-base: no read, no write.
    @Test func idleDisplaysDoNothing() async throws {
        let h = EngineHarness()
        await h.start()
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.gamma.writeCount == 0 && h.engine.activeTaskCount == 0)
        #expect(await h.boost())
        #expect(h.controller()?.baseline == newBase)                      // captured fresh at the next arm
    }
}
