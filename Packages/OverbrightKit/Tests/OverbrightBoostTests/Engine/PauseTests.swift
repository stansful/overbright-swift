// OverbrightBoostTests/Engine/PauseTests.swift — the user pause (ARCHITECTURE.md §3.8, §4.9): the engine is the only
// writer of `automations.pausedUntil` and keeps one sleep until the deadline; moving a slider ends the pause; a pause
// without a deadline lasts until Resume; nothing runs for it while off.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct PauseTests {
    @Test func pauseUntilADeadlineEndsByItself() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        let until = h.time.wallClock.addingTimeInterval(60)
        h.engine.pause(until: until, source: .menu)
        #expect(h.settings[AutomationSettings.pausedUntil] == until)
        #expect(h.engine.status.pausedUntil == until)
        #expect(h.engine.status.banner == .userPaused(until: until))
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.engine.pauseSlot.isRunning)
        await h.advance(.seconds(59), step: .milliseconds(500))
        #expect(h.settings[AutomationSettings.pausedUntil] == nil)
        #expect(h.codes.contains("pause.ended"))
        #expect(await h.boost())
    }

    @Test func resumeEndsThePause() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.engine.pause(until: h.time.wallClock.addingTimeInterval(3_600), source: .intent)
        await h.advance(.seconds(1))
        h.engine.resume(source: .intent)
        #expect(h.settings[AutomationSettings.pausedUntil] == nil)
        #expect(!h.engine.pauseSlot.isRunning)
        #expect(await h.boost())
    }

    @Test func movingASliderEndsThePause() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.engine.pause(until: nil, source: .menu)
        #expect(h.settings[AutomationSettings.pausedUntil] == .distantFuture)
        #expect(!h.engine.pauseSlot.isRunning)                            // no deadline, no sleep
        await h.advance(.seconds(1))
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
        #expect(h.settings[AutomationSettings.pausedUntil] == nil)
        #expect(await h.boost())
    }

    @Test func noDeadlineTaskWhileOff() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.pause(until: h.time.wallClock.addingTimeInterval(60), source: .menu)
        #expect(!h.engine.pauseSlot.isRunning && h.time.sleeperCount == 0)
        h.engine.setOn(true, source: .menu)
        #expect(h.engine.pauseSlot.isRunning)
        h.engine.setOn(false, source: .menu)
        #expect(!h.engine.pauseSlot.isRunning)
    }

    /// An expired deadline found at a reduction is cleared (relaunch after the pause ended).
    @Test func expiredDeadlineIsCleared() async throws {
        let h = EngineHarness()
        h.settings[AutomationSettings.pausedUntil] = h.time.wallClock.addingTimeInterval(-5)
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(h.settings[AutomationSettings.pausedUntil] == nil)
        #expect(await h.boost())
    }
}
