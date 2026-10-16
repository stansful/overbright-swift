// OverbrightBoostTests/Engine/AutoOffTests.swift — the auto-off timer (ARCHITECTURE.md §4.9; DESIGN.md §6): when the
// master turns on with `autoOffMinutes` set, one sleep until then; at the deadline the master goes off and the HUD gets
// `.timerEnded`; turning off first cancels it; without the setting nothing waits.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct AutoOffTests {
    @Test func timerTurnsOffAndTellsTheHUD() async throws {
        let h = EngineHarness()
        h.settings[AutomationSettings.autoOffMinutes] = 5
        await h.start()
        let on = h.time.wallClock
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.autoOffAt == on.addingTimeInterval(300))
        #expect(await h.boost())
        await h.advance(.seconds(290), step: .milliseconds(500))
        #expect(h.engine.status.isOn)
        await h.advance(.seconds(11), step: .milliseconds(100))
        #expect(!h.engine.status.isOn && h.engine.status.autoOffAt == nil)
        let change = try #require(h.engine.status.lastChange)
        #expect(change.kind == .timerEnded && change.source == .automation)
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.everyTableAtBase)
        #expect(h.engine.activeTaskCount == 0)
    }

    @Test func turningOffCancelsTheTimer() async throws {
        let h = EngineHarness()
        h.settings[AutomationSettings.autoOffMinutes] = 10
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.autoOffSlot.isRunning)
        h.engine.setOn(false, source: .panel)
        #expect(!h.engine.autoOffSlot.isRunning && h.engine.status.autoOffAt == nil)
        await h.advance(.seconds(700), step: .seconds(1))
        #expect(h.engine.status.lastChange == nil)
    }

    @Test func noTimerWithoutTheSetting() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.autoOffAt == nil && !h.engine.autoOffSlot.isRunning)
    }

    /// The deadline counts from the turn-on; a later level change does not restart it.
    @Test func levelChangesKeepTheDeadline() async throws {
        let h = EngineHarness()
        h.settings[AutomationSettings.autoOffMinutes] = 5
        await h.start()
        h.engine.setOn(true, source: .panel)
        let deadline = try #require(h.engine.status.autoOffAt)
        await h.advance(.seconds(60), step: .milliseconds(500))
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        #expect(h.engine.status.autoOffAt == deadline)
    }
}
