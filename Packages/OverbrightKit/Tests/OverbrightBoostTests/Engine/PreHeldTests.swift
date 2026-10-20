// OverbrightBoostTests/Engine/PreHeldTests.swift — the pre-held path of D6 (ARCHITECTURE.md §4.3, §4.7): something
// already holds EDR (an HDR video at H 2.6, our own Fill Light), so the first rung is armed, the movement test is
// skipped, the absolute gate applies, the cache is never written from a pre-held arm, and when the other source
// leaves and our rung does not hold, the display escalates with H0 := H. A re-gate after a lock or a wake measures
// H0 and the path again.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct PreHeldTests {
    /// Another source holds H at 2.6: gating at once on the first rung of the automatic ladder (T3 bright), ready after
    /// 1.5 s of stability.
    @Test func preHeldGatesWithoutMovement() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.preHeld = 2.6; $0.grant = 2.6 }
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(250))
        #expect(h.phase() == .gating(rung: 5))
        #expect(h.codes.contains("gate.preHeld"))
        await h.advance(.milliseconds(1_800))
        #expect(h.phase() == .ramping || h.phase() == .boosted)
        #expect(await h.boost())
        #expect(h.triggers.made.count == 1)
        #expect(h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)?.rung == nil)
    }

    /// Pre-held at H 2.6 and the other source leaves later; our T3 does not hold: the interlock lowers at once,
    /// and after 2.5 s below the needed headroom the display escalates from the current rung with H0 := H.
    @Test func otherSourceLeavingEscalates() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) {
            $0.preHeld = 2.6
            $0.preHeldLeavesAfter = .seconds(8)
            $0.respondingStrategies = [.metalOneShot]
        }
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.armedPreHeld == true)
        await h.advance(.seconds(6))                                     // the source leaves at 8 s
        let lowered = await h.advance(until: { h.liveFactor() == 1 }, limit: .seconds(3))
        #expect(lowered)                                                // H fell to 1: the baseline at once
        let escalated = await h.advance(until: { (h.controller()?.currentRung?.number ?? 5) != 5 }, limit: .seconds(6))
        #expect(escalated)
        #expect(h.codes.contains("gate.heldSourceLeft"))
        #expect(await h.boost())
        #expect(h.controller()?.currentRung?.number == 4)
        #expect(h.controller()?.idleHeadroom == 1)
        #expect(h.interlockViolations().isEmpty && h.orderViolations.isEmpty)
    }

    /// The source leaves but our rung holds the grant itself: no escalation at all.
    @Test func ourRungHoldingKeepsTheBoost() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.preHeld = 2.6; $0.preHeldLeavesAfter = .seconds(5) }
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(10))
        #expect(h.phase() == .boosted && h.triggers.made.count == 1)
        #expect(!h.codes.contains("gate.heldSourceLeft"))
    }

    /// Pre-held, then a lock and an unlock while the other source still holds H at 2.6: the re-gate measures H0
    /// again and gates with the absolute rule (a movement test above 2.6 would never pass).
    @Test func unlockWithTheSourceStillHoldingRegatesPreHeld() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.preHeld = 2.6; $0.grant = 2.6 }
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.armedPreHeld == true)
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        await h.advance(.seconds(2))
        h.signals.snapshot.isScreenLocked = false
        h.signals.emit(.unlocked)
        #expect(await h.boost(limit: .seconds(10)))
        #expect(h.controller()?.armedPreHeld == true && h.controller()?.idleHeadroom == 2.6)
        #expect(h.triggers.made.count == 1)                              // the kept trigger, re-presented
        #expect(h.interlockViolations().isEmpty && h.orderViolations.isEmpty)
    }

    /// The same across a sleep long enough for the trigger to go (the lock screen hides the video meanwhile): after
    /// the wake settle the re-gate's fresh reads are idle reads, and the source holding again makes it pre-held.
    @Test func wakeWithTheSourceStillHoldingRegatesPreHeld() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.preHeld = 2.6; $0.grant = 2.6 }
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.isSystemSleeping = true
        h.scripted.setOverride(1)
        h.signals.emit(.willSleep)
        await h.advance(.seconds(12))
        #expect(h.liveTriggers().isEmpty)                                // the linger removed it
        h.signals.snapshot.isSystemSleeping = false
        h.scripted.setOverride(nil)
        h.signals.emit(.didWake)
        #expect(await h.boost(limit: .seconds(10)))
        #expect(h.controller()?.armedPreHeld == true)
        #expect(h.phase() == .boosted && h.interlockViolations().isEmpty)
    }

    /// A normal arm whose kept trigger already holds H when the lock ends stays on the normal path with the H0 of
    /// its first arm (our own grant is not another source).
    @Test func ownKeptTriggerDoesNotMakeAReGatePreHeld() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.armedPreHeld == false)
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        await h.advance(.seconds(2))
        h.signals.snapshot.isScreenLocked = false
        h.signals.emit(.unlocked)
        #expect(await h.boost(limit: .seconds(10)))
        #expect(h.controller()?.armedPreHeld == false && h.controller()?.idleHeadroom == 1)
    }

    /// Our own EDR surface (Fill Light, the Welcome card) on the display counts as pre-held.
    @Test func ownEDRSurfaceIsPreHeld() async throws {
        let h = EngineHarness()
        let token = h.surfaces.hold(h.builtIn)
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(250))
        #expect(h.controller()?.armedPreHeld == true)
        #expect(h.phase() == .gating(rung: 5))
        token.cancel()
    }

    /// macOS 27 idles at 1.2 without any request: that is not pre-held, the normal gate needs H0 + 0.1.
    @Test func idleAtOnePointTwoIsNotPreHeld() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.idle = 1.2 }
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(250))
        #expect(h.controller()?.armedPreHeld == false)
        #expect(h.phase() == .arming(rung: 5))
        #expect(await h.boost())
        #expect(h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)?.rung == 5)
    }

    /// A stable 1.26 with nothing else: pre-held by the "≥ 1.25 and stable" rule.
    @Test func stableHighIdleIsPreHeld() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.idle = 1.26; $0.grant = 1.9 }
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(250))
        #expect(h.controller()?.armedPreHeld == true)
    }
}
