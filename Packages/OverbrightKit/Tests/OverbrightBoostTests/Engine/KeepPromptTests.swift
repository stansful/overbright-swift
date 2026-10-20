// OverbrightBoostTests/Engine/KeepPromptTests.swift — "Keep this level?" by the owner's rule of 2026-10-20
// (ARCHITECTURE.md §4.9; DESIGN.md §6): a level change a person makes (the panel, the menu, a shortcut, an intent,
// Settings) away from Standard publishes `pendingConfirmation` on the display whose control moved; without an answer
// that display goes back to STANDARD after 10 s (a screen that turns white or dark comes back without anyone reading
// the prompt); a drag restarts the 10 s from its last step; a change back to Standard ends the question; turning on
// with a level away from Standard asks too. Levels inside the range already kept on that display, macOS build and
// winning rung ask nothing (2026-10-21). The harness's default (`asksToKeep: false`) is switched on here.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct KeepPromptTests {
    private let brightRoom = LevelPreset.brightRoom.position
    private let max = LevelPreset.max.position
    private let dimHalf = LevelPosition(-0.5)
    private let msi = DisplayFixture.Keys.mpg322ux

    /// A started harness that asks, on, with its first question (turning on) kept: the built-in boosts at Bright room.
    private func onAndKept(_ h: EngineHarness = EngineHarness(asksToKeep: true)) async -> EngineHarness {
        await h.start(on: true)
        h.engine.keepLevel()
        return h
    }

    /// A boosted harness (its winning rung learned) whose kept range on the built-in reaches `level`.
    private func keptAt(_ level: LevelPosition) async throws -> EngineHarness {
        let h = await onAndKept()
        #expect(await h.boost())
        try #require(rung(h) != nil)
        h.engine.setLevel(level, for: h.builtIn, source: .panel)
        h.engine.keepLevel()
        try #require(h.engine.status.pendingConfirmation == nil)
        return h
    }

    private func rung(_ h: EngineHarness) -> Int? {
        h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)?.rung
    }

    private func keptRange(_ h: EngineHarness) -> KeptLevelRange? {
        h.settings[DisplaySettings.perDisplay][h.builtIn]?.keptRange
    }

    // MARK: Who asks

    /// A boost from the panel asks on that display, with Standard as the level to go back to.
    @Test func aBoostAsksOnTheMovedDisplay() async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == h.builtIn)
        #expect(pending.previousLevels == [h.builtIn: .standard])
        #expect(pending.deadline == h.time.wallClock.addingTimeInterval(10))
        #expect(h.codes.contains("keep.asked"))
        #expect(h.engine.confirmationSlot.isRunning)
    }

    /// Dimming asks too: every change away from Standard, not only a very dark one.
    @Test func aDimAsks() async throws {
        let h = await onAndKept()
        h.engine.setLevel(dimHalf, for: h.builtIn, source: .menu)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == h.builtIn && pending.previousLevels == [h.builtIn: .standard])
    }

    /// Every way a person moves a level asks: the panel, the menu, a shortcut, an intent and Settings.
    @Test(arguments: [ControlSource.panel, .menu, .shortcut, .intent, .settings])
    func everyPersonSourceAsks(_ source: ControlSource) async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: source)
        #expect(h.engine.status.pendingConfirmation?.display == h.builtIn)
    }

    /// Automations, Focus, Welcome and the launch behaviour do not ask when they move a level (they resume a level that
    /// was already on screen, or apply one the person chose there).
    @Test(arguments: [ControlSource.automation, .focusFilter, .welcome, .launch, .statusItem])
    func otherSourcesDoNotAskWhenTheyMoveALevel(_ source: ControlSource) async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: source)
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(!h.engine.confirmationSlot.isRunning)
    }

    /// Turning on with a level away from Standard asks, from every source a person turns on with (a login launch with
    /// "turn on", the status item, Welcome and Focus included); automations never turn on with a question.
    @Test(arguments: [ControlSource.panel, .menu, .shortcut, .intent, .settings, .focusFilter, .welcome, .launch,
                      .statusItem])
    func turningOnAsks(_ source: ControlSource) async throws {
        let h = EngineHarness(asksToKeep: true)
        await h.start()
        #expect(h.engine.storedLevel(of: h.builtIn) == brightRoom)
        h.engine.setOn(true, source: source)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == h.builtIn && pending.previousLevels == [h.builtIn: .standard])
    }

    /// Turning on at Standard, or from an automation, asks nothing.
    @Test func turningOnAtStandardOrFromAnAutomationDoesNotAsk() async throws {
        let h = EngineHarness(asksToKeep: true)
        await h.start()
        h.engine.setOn(true, source: .automation)
        #expect(h.engine.status.pendingConfirmation == nil)
        h.engine.setOn(false, source: .menu)
        h.setPreferences { $0.level = .standard }
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.pendingConfirmation == nil)
    }

    // MARK: Going back

    /// Unanswered: the boost runs meanwhile, and 10 s after the change the display is back at STANDARD (not at the
    /// level before the change), the table at its base and no trigger left.
    @Test func unansweredGoesBackToStandardNotThePreviousLevel() async throws {
        let h = await onAndKept()
        #expect(await h.boost())
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(9_900), step: .milliseconds(100))
        #expect(h.engine.status.pendingConfirmation != nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == max)
        #expect(h.phase() == .boosted)
        await h.advance(.milliseconds(200))
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(h.engine.storedLevel(of: h.builtIn) != brightRoom)
        #expect(h.codes.contains("keep.reverted"))
        #expect(await h.advance(until: { h.phase() == .idle }, limit: .seconds(2)))
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.orderViolations.isEmpty)
    }

    /// A dim goes back to Standard too.
    @Test func anUnansweredDimGoesBackToStandard() async throws {
        let h = await onAndKept()
        h.engine.setLevel(dimHalf, for: h.builtIn, source: .shortcut)
        await h.advance(.milliseconds(10_100), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(await h.advance(until: { h.phase() == .idle }, limit: .seconds(2)))
        #expect(h.everyTableAtBase)
    }

    /// A drag is one change: every step moves the deadline to 10 s after it, so the display goes back 10 s after the
    /// LAST step, not the first.
    @Test func aDragRestartsTheTenSeconds() async throws {
        let h = await onAndKept()
        for step in 1...5 {
            h.engine.setLevel(LevelPosition(0.5 + 0.1 * Double(step)), for: h.builtIn, source: .panel)
            #expect(h.engine.status.pendingConfirmation?.deadline == h.time.wallClock.addingTimeInterval(10))
            await h.advance(.seconds(1), step: .milliseconds(100))
        }
        // The first step was 5 s ago: 9.9 s after the last one the level still stands.
        await h.advance(.milliseconds(8_900), step: .milliseconds(100))
        #expect(h.engine.status.pendingConfirmation != nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPosition(1.0))
        await h.advance(.milliseconds(200))
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(h.codes.filter { $0 == "keep.reverted" }.count == 1)
    }

    /// A change back to Standard ends the question: the prompt goes and nothing goes back later; the next change beyond
    /// the kept range asks again.
    @Test func backToStandardEndsTheQuestion() async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        await h.advance(.seconds(2))
        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(!h.engine.confirmationSlot.isRunning)
        #expect(h.codes.contains("keep.ended"))
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(!h.codes.contains("keep.reverted"))
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.display == h.builtIn)
    }

    /// Go Back returns to Standard at once.
    @Test func goBackReturnsToStandardAtOnce() async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: .intent)
        h.engine.revertLevel()
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(!h.engine.confirmationSlot.isRunning)
    }

    /// Back to Standard (the master off) while it asks goes back too, and leaves no task behind.
    @Test func turningOffWhileAskingGoesBack() async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        h.engine.returnToStandard(source: .shortcut)
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        await h.advance(.seconds(1))
        #expect(h.engine.activeTaskCount == 0 && h.time.sleeperCount == 0)
    }

    // MARK: Keep

    /// Keep keeps the level past the 10 s; the next change beyond the kept range asks again.
    @Test func keepKeeps() async throws {
        let h = await onAndKept()
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        h.engine.keepLevel()
        #expect(h.engine.status.pendingConfirmation == nil && !h.engine.confirmationSlot.isRunning)
        #expect(h.codes.contains("keep.kept"))
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == max)
        #expect(h.phase() == .boosted)
        h.engine.setLevel(dimHalf, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation != nil)
    }

    // MARK: The kept range

    /// Inside the range kept on this display, build and rung nothing asks: the boost side up to the kept boost, a dim
    /// back to Standard, and a drag within the range.
    @Test func insideTheKeptRangeDoesNotAsk() async throws {
        let h = try await keptAt(LevelPosition(0.8))
        let asked = h.codes.filter { $0 == "keep.asked" }.count
        for level in [LevelPosition(0.3), LevelPosition(0.8), brightRoom, .standard, LevelPosition(0.7)] {
            h.engine.setLevel(level, for: h.builtIn, source: .panel)
            #expect(h.engine.status.pendingConfirmation == nil)
        }
        #expect(h.codes.filter { $0 == "keep.asked" }.count == asked)
        #expect(!h.engine.confirmationSlot.isRunning)
    }

    /// Brighter than the kept boost asks; moving back into the range ends that question.
    @Test func beyondTheKeptRangeAsks() async throws {
        let h = try await keptAt(LevelPosition(0.6))
        h.engine.setLevel(LevelPosition(0.9), for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.previousLevels == [h.builtIn: .standard])
        h.engine.setLevel(LevelPosition(0.6), for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation == nil && !h.engine.confirmationSlot.isRunning)
        await h.advance(.seconds(11), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPosition(0.6))
    }

    /// Keep widens the range: after keeping a brighter level, levels up to it ask nothing; the build and rung are
    /// stored with it.
    @Test func keepWidensTheRange() async throws {
        let h = try await keptAt(LevelPosition(0.6))
        h.engine.setLevel(LevelPosition(0.9), for: h.builtIn, source: .panel)
        h.engine.keepLevel()
        let range = try #require(keptRange(h))
        #expect(range.highestBoost == LevelPosition(0.9) && range.lowestDim == nil)
        #expect(range.osBuild == h.fixture.machine.osBuild && range.rung == rung(h))
        h.engine.setLevel(LevelPosition(0.85), for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation == nil)
        h.engine.setLevel(max, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation != nil)
    }

    /// A range kept on another macOS build no longer holds: a level inside it asks, and Keep starts a new range.
    @Test func aBuildChangeClearsTheRange() async throws {
        let h = try await keptAt(max)
        h.setPreferences { $0.keptRange?.osBuild = "25A000" }
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.display == h.builtIn)
        h.engine.keepLevel()
        let range = try #require(keptRange(h))
        #expect(range.osBuild == h.fixture.machine.osBuild && range.highestBoost == brightRoom)
    }

    /// A different winning rung clears the range too.
    @Test func aRungChangeClearsTheRange() async throws {
        let h = try await keptAt(max)
        let kept = try #require(rung(h))
        h.engine.strategyCache.forget()
        h.engine.strategyCache.recordWin(rung: kept == 7 ? 6 : 7, for: h.builtIn, osBuild: h.fixture.machine.osBuild)
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.display == h.builtIn)
    }

    /// The dim side has its own edge: darker than the lowest kept dim asks, lighter does not; Keep moves the edge down.
    @Test func theDimSideKeepsItsOwnEdge() async throws {
        let h = try await keptAt(dimHalf)
        #expect(keptRange(h)?.lowestDim == dimHalf)
        h.engine.setLevel(LevelPosition(-0.3), for: h.builtIn, source: .menu)
        #expect(h.engine.status.pendingConfirmation == nil)
        h.engine.setLevel(LevelPosition(-0.7), for: h.builtIn, source: .menu)
        #expect(h.engine.status.pendingConfirmation != nil)
        h.engine.keepLevel()
        #expect(keptRange(h)?.lowestDim == LevelPosition(-0.7))
        h.engine.setLevel(LevelPosition(-0.6), for: h.builtIn, source: .menu)
        #expect(h.engine.status.pendingConfirmation == nil)
    }

    /// Turning on with a stored level inside the kept range asks nothing; beyond it, turning on asks.
    @Test func turningOnInsideTheRangeDoesNotAsk() async throws {
        let h = try await keptAt(LevelPosition(0.8))
        h.engine.setOn(false, source: .menu)
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.pendingConfirmation == nil)
        h.engine.setOn(false, source: .menu)
        h.setPreferences { $0.level = max }
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.display == h.builtIn)
    }

    // MARK: Several displays

    /// The prompt shows on the display whose control moved; a later change on another display moves it there and adds
    /// that display to the question, so both go back to Standard unanswered.
    @Test func thePromptsDisplayIsTheMovedOne() async throws {
        let h = await onAndKept(EngineHarness(fixture: .russianNames, asksToKeep: true))
        h.engine.setLevel(max, for: msi, source: .panel)
        #expect(h.engine.status.pendingConfirmation?.display == msi)
        #expect(h.engine.status.pendingConfirmation?.previousLevels == [msi: .standard])
        h.engine.setLevel(dimHalf, for: h.builtIn, source: .panel)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == h.builtIn)
        #expect(pending.previousLevels == [msi: .standard, h.builtIn: .standard])
        await h.advance(.milliseconds(10_100), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: msi) == .standard && h.engine.storedLevel(of: h.builtIn) == .standard)
    }

    /// Linked levels: one level for every display, so the question covers them all, shows on the moved display, and
    /// unanswered the linked level goes back to Standard.
    @Test func linkedLevelsGoBackToStandard() async throws {
        let h = EngineHarness(fixture: .russianNames, asksToKeep: true)
        h.settings[DisplaySettings.linkLevels] = true
        h.settings[DisplaySettings.linkedLevel] = brightRoom
        _ = await onAndKept(h)
        h.engine.setLevel(max, for: msi, source: .panel)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == msi)
        #expect(Set(pending.previousLevels.keys) == [h.builtIn, msi] && Set(pending.previousLevels.values) == [.standard])
        await h.advance(.milliseconds(10_100), step: .milliseconds(100))
        #expect(h.engine.status.pendingConfirmation == nil)
        #expect(h.settings[DisplaySettings.linkedLevel] == .standard)
    }

    /// Turning on with two displays away from Standard asks about both, on no single display.
    @Test func turningOnWithTwoDisplaysAsksAboutBoth() async throws {
        let h = EngineHarness(fixture: .russianNames, asksToKeep: true)
        h.setPreferences(msi) { $0.level = dimHalf }
        await h.start()
        h.engine.setOn(true, source: .shortcut)
        let pending = try #require(h.engine.status.pendingConfirmation)
        #expect(pending.display == nil)
        #expect(pending.previousLevels == [h.builtIn: .standard, msi: .standard])
    }
}
