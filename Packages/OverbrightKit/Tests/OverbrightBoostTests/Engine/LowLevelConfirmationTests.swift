// OverbrightBoostTests/Engine/LowLevelConfirmationTests.swift — "Keep this level?" (ARCHITECTURE.md §4.9, §5.9;
// DESIGN.md §6): a change from the panel, the menu, a shortcut or an intent that takes a display from at least 10 % to
// below 10 % of Standard light publishes `pendingLowLevel`; the engine reverts by itself after 10 s.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct LowLevelConfirmationTests {
    private let veryDark = LevelPosition(-0.9)                             // ≈ 4.9 % of Standard light

    @Test func veryDarkLevelAsksAndRevertsAfterTenSeconds() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(LevelMapping.dimLight(for: veryDark) < EngineTiming.lowLevelThreshold)
        h.engine.setLevel(veryDark, for: h.builtIn, source: .panel)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.display == h.builtIn)
        #expect(pending.previousLevels[h.builtIn] == LevelPreset.brightRoom.position)
        #expect(pending.deadline == h.time.wallClock.addingTimeInterval(10))
        await h.advance(.milliseconds(9_900), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == veryDark)
        await h.advance(.milliseconds(200))
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPreset.brightRoom.position)
        #expect(h.codes.contains("lowLevel.reverted"))
    }

    @Test func keepConfirms() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(veryDark, for: h.builtIn, source: .shortcut)
        h.engine.keepLowLevel()
        #expect(h.engine.status.pendingLowLevel == nil)
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == veryDark)
        #expect(h.phase() == .dimmed)
    }

    @Test func goBackRevertsAtOnce() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.3), for: h.builtIn, source: .panel)
        h.engine.setDimLight(0.03, for: h.builtIn, source: .intent)
        #expect(h.engine.status.pendingLowLevel != nil)
        h.engine.revertLowLevel()
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPosition(-0.3))
        #expect(!h.engine.lowLevelSlot.isRunning)
    }

    @Test func onlyACrossingFromTheListedSourcesAsks() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(veryDark, for: h.builtIn, source: .settings)
        #expect(h.engine.status.pendingLowLevel == nil)
        h.engine.setLevel(LevelPosition(-0.95), for: h.builtIn, source: .panel)  // already below 10 %
        #expect(h.engine.status.pendingLowLevel == nil)
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPosition(-0.7), for: h.builtIn, source: .menu)    // ≈ 18 %: above the threshold
        #expect(h.engine.status.pendingLowLevel == nil)
    }

    /// Back to Standard answers the question by going back, and turning off never leaves the prompt behind.
    @Test func backToStandardRevertsThePendingLevel() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(veryDark, for: h.builtIn, source: .menu)
        h.engine.returnToStandard(source: .shortcut)
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPreset.brightRoom.position)
        await h.advance(.seconds(1))
        #expect(h.engine.activeTaskCount == 0 && h.time.sleeperCount == 0)
    }
}
