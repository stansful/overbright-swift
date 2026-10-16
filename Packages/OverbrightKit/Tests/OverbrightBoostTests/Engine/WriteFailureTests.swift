// OverbrightBoostTests/Engine/WriteFailureTests.swift — WindowServer refusing a write (ARCHITECTURE.md §4.5 invariants 2
// and 4, §9.1 "every sequence ending in off leaves every table equal to its baseline"): a failed ramp step lands on the
// baseline before any window goes and before the ramp claims its phase; a ramp to anything else retries; a failed
// baseline write keeps the display marked and its trigger until a later write succeeds; a table that cannot be read
// leaves the display for the next reduction to retry.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct WriteFailureTests {
    private static let failure = GammaError.coreGraphics(code: 1000)

    /// A step of the disarm ramp fails: the display still ends idle at its baseline, with no window and no task.
    @Test func aFailedDisarmStepStillEndsAtTheBaseline() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        h.engine.setOn(false, source: .panel)
        await h.advance(.milliseconds(60))
        h.gamma.failNextWrite(with: Self.failure)
        await h.advance(.seconds(3))
        #expect(h.codes.contains("ramp.writeFailed"))
        #expect(h.phase() == .idle && h.everyTableAtBase && h.liveFactor() == 1)
        #expect(h.liveTriggers().isEmpty && h.engine.activeTaskCount == 0)
        #expect(h.engine.ledger.entries().isEmpty && h.orderViolations.isEmpty)
    }

    /// The same for an un-dim.
    @Test func aFailedUndimStepStillEndsAtTheBaseline() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.phase() == .dimmed)
        h.engine.setOn(false, source: .panel)
        await h.advance(.milliseconds(60))
        h.gamma.failNextWrite(with: Self.failure)
        await h.advance(.seconds(3))
        #expect(h.phase() == .idle && h.everyTableAtBase && h.engine.activeTaskCount == 0)
    }

    /// A step of the boost ramp fails: the display lands on its baseline (never "boosted" at a stale gain), then the
    /// ramp is retried and reaches its target, flicker-safe and within the interlock.
    @Test func aFailedBoostStepIsRetried() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { h.phase() == .ramping }))
        await h.advance(.milliseconds(60))
        h.gamma.failNextWrite(with: Self.failure)
        await h.advance(.milliseconds(40))
        #expect(h.phase() == .ramping)
        #expect(await h.boost())
        #expect(h.codes.contains("ramp.retried"))
        let factor = try #require(h.controller()?.appliedFactor)
        #expect(factor > 1 && abs((h.liveFactor() ?? 0) - factor) < 1e-4)
        #expect(h.interlockViolations().isEmpty && h.orderViolations.isEmpty)
    }

    /// The shield's baseline write fails: the display stays marked as scaled (the ledger too) and keeps its trigger;
    /// the linger writes the baseline again before removing it.
    @Test func aFailedShieldWriteKeepsTheDisplayMarked() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.failNextWrite(with: Self.failure)
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        #expect(h.controller()?.isScaledOrDimmed == true && !h.engine.ledger.entries().isEmpty)
        #expect(h.liveTriggers().count == 1)
        await h.advance(.seconds(11))
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty && h.engine.ledger.entries().isEmpty)
        #expect(h.controller()?.isScaledOrDimmed == false && h.orderViolations.isEmpty)
    }

    /// A write that keeps failing trips the display (repair budget) instead of retrying forever.
    @Test func aWriteThatKeepsFailingTripsTheDisplay() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        for _ in 0..<40 where !(h.phase()?.isFailed ?? false) {
            h.gamma.failNextWrite(with: Self.failure)
            await h.advance(.milliseconds(50))
        }
        #expect(h.phase() == .failed(.repairBudgetExceeded) || h.phase() == .failed(.oscillation))
        #expect(h.engine.activeTaskCount == 0 && h.orderViolations.isEmpty)
    }

    /// The same while boosted: whichever trip ends it, no trigger goes while its table is above the base, and the
    /// display ends at its baseline with no window.
    @Test func aBoostWriteThatKeepsFailingTripsInOrder() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        var level = 0.9
        for _ in 0..<40 where !(h.phase()?.isFailed ?? false) {
            level = level > 0.8 ? 0.7 : 0.9
            h.engine.setLevel(LevelPosition(level), for: h.builtIn, source: .panel)
            h.gamma.failNextWrite(with: Self.failure)
            await h.advance(.milliseconds(120))
        }
        #expect(h.phase()?.isFailed == true)
        await h.advance(.seconds(1))
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty && h.engine.activeTaskCount == 0)
        #expect(h.orderViolations.isEmpty && h.interlockViolations().isEmpty)
    }

    /// A trip whose landing WindowServer refuses keeps the trigger with the scaled table (§4.5 invariant 2); the next
    /// reduction lands it and only then orders the trigger out.
    @Test func aTripWhoseLandingFailsKeepsTheTriggerUntilItLands() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.failNextWrite(with: Self.failure)
        h.controller()?.fail(.repairBudgetExceeded)
        #expect(h.phase() == .failed(.repairBudgetExceeded) && (h.liveFactor() ?? 1) > 1)
        #expect(h.liveTriggers().count == 1 && !h.engine.ledger.entries().isEmpty && h.orderViolations.isEmpty)
        #expect(h.codes.contains("order.windowsKept"))
        await h.advance(.milliseconds(200))
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty && h.engine.ledger.entries().isEmpty)
        #expect(h.phase() == .failed(.repairBudgetExceeded) && h.engine.activeTaskCount == 0)
        #expect(h.orderViolations.isEmpty)
    }

    /// The occlusion's baseline write failed, then a dim is chosen and its landing fails too: the trigger stays until
    /// the dim ramp has the table below the base, then goes (found by the property test, seed 4242).
    @Test func aDimAfterAFailedOcclusionWriteRemovesTheTriggerInOrder() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.failNextWrite(with: Self.failure)
        h.triggers.setOccluded(true, on: h.builtIn)
        #expect(h.phase() == .suspended(.occluded) && h.controller()?.isScaledOrDimmed == true)
        h.gamma.failNextWrite(with: Self.failure)
        h.engine.setDimLight(0.5, for: h.builtIn, source: .menu)
        await h.advance(.seconds(2))
        #expect(h.phase() == .dimmed && h.liveTriggers().isEmpty && (h.liveFactor() ?? 1) < 1)
        #expect(h.orderViolations.isEmpty && h.codes.contains("order.windowsKept"))
    }

    /// The table cannot be read when the arm starts: the display stays idle without keeping the target, so the next
    /// reduction arms (not only a change of the target).
    @Test func anUnreadableTableRetriesOnTheNextReduction() async throws {
        let h = EngineHarness()
        await h.start()
        let base = try #require(h.base())
        h.gamma.removeDisplay(h.id(h.builtIn))
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(500))
        #expect(h.phase() == .idle && h.codes.contains("arm.couldNotStart") && h.triggers.made.isEmpty)
        h.gamma.addDisplay(h.id(h.builtIn), base: base)
        h.engine.reduceNow()
        #expect(await h.boost())
    }
}
