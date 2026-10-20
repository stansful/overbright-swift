// OverbrightBoostTests/Engine/FirstBoostConfirmationTests.swift — "Keep this level?" on a display's first boost per
// macOS build (ARCHITECTURE.md §4.9; DESIGN.md §6): a boost from the panel, the menu, a shortcut or an intent on a
// display whose `boostConfirmedBuild` is not the running build publishes `pendingLowLevel` with
// `firstBoostDisplays`; unanswered, the engine returns those displays to Standard after 10 s by itself (a display that
// turns white when boosted comes back without anyone reading the prompt); Keep records the build. The harness's
// default confirmation is switched off here.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct FirstBoostConfirmationTests {
    private let veryDark = LevelPosition(-0.9)                             // ≈ 4.9 % of Standard light
    private let brightRoom = LevelPreset.brightRoom.position

    /// A started harness with nothing confirmed, the built-in stored at Standard.
    private func atStandard(_ h: EngineHarness = EngineHarness(confirmsFirstBoost: false)) async -> EngineHarness {
        h.setPreferences { $0.level = .standard }
        await h.start()
        return h
    }

    private func confirmedBuild(_ h: EngineHarness, _ key: DisplayKey? = nil) -> String? {
        h.settings[DisplaySettings.perDisplay][key ?? h.builtIn]?.boostConfirmedBuild
    }

    /// A panel boost from Standard asks about that display, with Standard as the level to go back to.
    @Test func aPanelBoostFromStandardAsks() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [h.builtIn])
        #expect(pending.display == h.builtIn)
        #expect(pending.previousLevels[h.builtIn] == .standard)
        #expect(pending.deadline == h.time.wallClock.addingTimeInterval(10))
        #expect(h.codes.contains("firstBoost.asked"))
        #expect(h.engine.lowLevelSlot.isRunning)
    }

    /// Unanswered: the display boosts meanwhile, and 10 s later it is back at Standard with the table at its base and
    /// no trigger left; nothing is recorded.
    @Test func noKeepWithinTenSecondsReturnsToStandard() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(9_900), step: .milliseconds(100))
        #expect(h.engine.status.pendingLowLevel != nil)
        #expect(h.phase() == .boosted)
        #expect((h.liveFactor() ?? 1) > 1)
        await h.advance(.milliseconds(200))
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(h.codes.contains("firstBoost.reverted"))
        let idle = await h.advance(until: { h.phase() == .idle }, limit: .seconds(2))
        #expect(idle)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(confirmedBuild(h) == nil)
        #expect(h.orderViolations.isEmpty)
    }

    /// Keep records the running build; the boost stays, and a later boost on this build does not ask.
    @Test func keepRecordsTheBuildAndALaterBoostDoesNotAsk() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingLowLevel != nil)
        h.engine.keepLowLevel()
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(!h.engine.lowLevelSlot.isRunning)
        #expect(confirmedBuild(h) == h.fixture.machine.osBuild)
        #expect(h.codes.contains("firstBoost.kept"))
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == brightRoom)
        #expect(h.phase() == .boosted)

        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .shortcut)
        #expect(h.engine.status.pendingLowLevel == nil)
        h.engine.setOn(false, source: .menu)
        h.engine.setOn(true, source: .menu)
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.codes.filter { $0 == "firstBoost.asked" }.count == 1)
    }

    /// A build kept on an earlier macOS asks again after the update.
    @Test func anotherMacOSBuildAsksAgain() async throws {
        let updated = MachineIdentity(model: "Mac16,5", osBuild: "26B100", osMajor: 27, osMinor: 1, osPatch: 0)
        let h = EngineHarness(machine: updated, confirmsFirstBoost: false)
        h.setPreferences { $0.boostConfirmedBuild = h.fixture.machine.osBuild }
        #expect(h.fixture.machine.osBuild != updated.osBuild)
        _ = await atStandard(h)
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .intent)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [h.builtIn])
        h.engine.keepLowLevel()
        #expect(confirmedBuild(h) == "26B100")
    }

    /// Turning the master on with a boost level stored asks too; unanswered, the stored level becomes Standard.
    @Test func turningOnWithAStoredBoostLevelAsks() async throws {
        let h = EngineHarness(confirmsFirstBoost: false)
        await h.start()
        #expect(h.engine.storedLevel(of: h.builtIn) == brightRoom)
        h.engine.setOn(true, source: .shortcut)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [h.builtIn])
        #expect(pending.previousLevels[h.builtIn] == .standard)
        await h.advance(.milliseconds(10_100), step: .milliseconds(100))
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(h.codes.contains("firstBoost.reverted"))
        let idle = await h.advance(until: { h.phase() == .idle }, limit: .seconds(2))
        #expect(idle && h.everyTableAtBase)
    }

    /// Every way a person starts a boost asks: a login launch with "turn on", the status item's toggle, Settings and a
    /// Focus filter too, so a display that turns white after a macOS update comes back whichever way it began.
    @Test(arguments: [ControlSource.launch, .statusItem, .settings, .welcome])
    func turningOnFromAnyPersonSourceAsks(_ source: ControlSource) async throws {
        let h = EngineHarness(confirmsFirstBoost: false)
        await h.start()
        h.engine.setOn(true, source: source)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [h.builtIn])
    }

    /// A Focus filter's level asks as well.
    @Test func aFocusFilterBoostAsks() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .focusFilter)
        #expect(h.engine.status.pendingLowLevel?.firstBoostDisplays == [h.builtIn])
    }

    /// Automations only resume a level that was already on screen: they never ask.
    @Test func automationsDoNotAsk() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .automation)
        #expect(h.engine.status.pendingLowLevel == nil)
    }

    /// Dragging back to Standard while it asks ends the boost it asked about: the prompt goes, nothing reverts later
    /// and nothing is recorded; the next boost asks again.
    @Test func backToStandardWhileAskingDropsThePrompt() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingLowLevel != nil)
        await h.advance(.seconds(2))
        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(!h.engine.lowLevelSlot.isRunning)
        #expect(h.codes.contains("firstBoost.ended"))
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(!h.codes.contains("firstBoost.reverted"))
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        #expect(confirmedBuild(h) == nil)
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingLowLevel?.firstBoostDisplays == [h.builtIn])
    }

    /// Back to Standard (the master off) while it asks reverts the level, like any pending confirmation.
    @Test func turningOffWhileAskingReverts() async throws {
        let h = await atStandard()
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        h.engine.returnToStandard(source: .shortcut)
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.engine.storedLevel(of: h.builtIn) == .standard)
        await h.advance(.seconds(1))
        #expect(h.engine.activeTaskCount == 0 && h.time.sleeperCount == 0)
    }

    /// A display that cannot boost (Sidecar: no transfer table) never asks; with every display boosted at once, only
    /// the one that can boost is asked about.
    @Test func aDisplayThatCannotBoostDoesNotAsk() async throws {
        let h = EngineHarness(fixture: .sidecar, confirmsFirstBoost: false)
        let sidecar = DisplayFixture.Keys.sidecar
        await h.start()
        let verdict = try #require(h.engine.lastDecision?.displays[sidecar]?.eligibility.verdict)
        #expect(!verdict.allowsBoost)
        h.engine.setLevel(.standard, for: nil, source: .settings)
        h.engine.setLevel(brightRoom, for: sidecar, source: .panel)
        #expect(h.engine.status.pendingLowLevel == nil)
        h.engine.setLevel(brightRoom, for: nil, source: .menu)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [h.builtIn])
        #expect(pending.display == h.builtIn)
    }

    /// Linked levels: one level for every display, so an unanswered first boost of one display returns the linked
    /// level to Standard, whatever the order of the displays.
    @Test func linkedLevelsReturnToStandard() async throws {
        let h = EngineHarness(fixture: .russianNames, confirmsFirstBoost: false)
        let msi = DisplayFixture.Keys.mpg322ux
        EngineHarness.confirmFirstBoost(of: [h.builtIn], build: h.fixture.machine.osBuild, in: h.settings)
        h.settings[DisplaySettings.linkLevels] = true
        h.settings[DisplaySettings.linkedLevel] = brightRoom
        await h.start()
        h.engine.setOn(true, source: .panel)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays == [msi])
        #expect(Set(pending.previousLevels.values) == [.standard])
        await h.advance(.milliseconds(10_100), step: .milliseconds(100))
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.settings[DisplaySettings.linkedLevel] == .standard)
    }

    /// The very dark prompt still asks, and Keep there confirms the level without recording a build; the first boost
    /// afterwards still asks.
    @Test func theLowLevelPromptStillWorksAndItsKeepRecordsNothing() async throws {
        let h = EngineHarness(confirmsFirstBoost: false)
        await h.start()
        h.engine.setLevel(veryDark, for: h.builtIn, source: .panel)
        let pending = try #require(h.engine.status.pendingLowLevel)
        #expect(pending.firstBoostDisplays.isEmpty)
        #expect(pending.previousLevels[h.builtIn] == brightRoom)
        h.engine.keepLowLevel()
        #expect(h.engine.status.pendingLowLevel == nil)
        #expect(h.codes.contains("lowLevel.kept") && !h.codes.contains("firstBoost.kept"))
        #expect(confirmedBuild(h) == nil)
        await h.advance(.seconds(12), step: .milliseconds(100))
        #expect(h.engine.storedLevel(of: h.builtIn) == veryDark)
        h.engine.setLevel(brightRoom, for: h.builtIn, source: .panel)
        #expect(h.engine.status.pendingLowLevel?.firstBoostDisplays == [h.builtIn])
    }
}
