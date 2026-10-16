// OverbrightAppShellTests/HUDLowLevelPromptTests.swift — "Keep this level?" (DESIGN.md §6, §12.9; ARCHITECTURE.md §4.9):
// it appears while the engine has a pending confirmation, counts down to the deadline once per second, Keep and Go
// Back answer through the engine, it closes when the engine clears the confirmation (the engine reverts by itself),
// VoiceOver hears it, and it holds the HUD's place. Driven by `ManualTimeSource`; no window is ordered in.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct LowLevelPromptTests {
    private func setup() -> (OverbrightServices, PreviewBoostControl, ManualTimeSource, Box) {
        let time = ManualTimeSource()
        let posted = Box()
        let boost = PreviewBoostControl(fixture: .builtinXDRLidOpen)
        let services = OverbrightServices(
            settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(), machine: DisplayFixture.ownerMachine,
            time: time, journal: RingBufferJournal(), announcer: Announcer(post: { posted.lines.append($0) }, now: { 0 }),
            ownEDRSurfaces: OwnEDRSurfaces(), displays: FakeDisplayDirectory(fixture: .builtinXDRLidOpen),
            signals: FakeSystemSignals(), boost: boost, fillLight: PreviewFillLightControl(),
            shortcuts: PreviewShortcutCenter(), updates: PreviewUpdateChecking())
        return (services, boost, time, posted)
    }

    private func pending(_ services: OverbrightServices, in seconds: TimeInterval = 10) -> LowLevelConfirmation {
        LowLevelConfirmation(display: DisplayFixture.Keys.builtIn,
                             previousLevels: [DisplayFixture.Keys.builtIn: LevelPosition(0.5)],
                             deadline: services.time.wallClock.addingTimeInterval(seconds))
    }

    @Test func thePromptAppearsCountsDownAndClosesWhenTheEngineReverts() async throws {
        let (services, boost, time, posted) = setup()
        let slot = HUDSlot()
        let prompt = LowLevelPromptController(services: services, slot: slot)
        prompt.presentsWindows = false
        prompt.start()
        #expect(prompt.shown == nil)
        boost.status.pendingLowLevel = pending(services)
        #expect(await eventually { prompt.shown != nil })
        #expect(prompt.secondsLeft == 10 && slot.occupant == .prompt)
        #expect(posted.lines == [LowLevelPromptText.announcement(10)])
        #expect(posted.lines.first?.contains("10") == true)
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .seconds(3))
        #expect(await eventually { prompt.secondsLeft == 7 })
        boost.status.pendingLowLevel = nil                                // the engine reverted at its deadline
        #expect(await eventually { prompt.shown == nil })
        #expect(slot.occupant == nil && time.sleeperCount == 0)
        prompt.stop()
    }

    @Test func keepAndGoBackAnswerThroughTheEngine() {
        let (services, boost, _, _) = setup()
        let prompt = LowLevelPromptController(services: services, slot: HUDSlot())
        prompt.presentsWindows = false
        boost.status.pendingLowLevel = pending(services)
        prompt.update(boost.status.pendingLowLevel)
        prompt.keep()
        #expect(boost.calls == ["keepLowLevel"] && prompt.shown == nil)
        boost.status.pendingLowLevel = pending(services, in: 8)
        prompt.update(boost.status.pendingLowLevel)
        #expect(prompt.secondsLeft == 8)
        prompt.goBack()
        #expect(boost.calls == ["keepLowLevel", "revertLowLevel"] && prompt.shown == nil)
    }

    @Test func secondsRoundUpAndNeverGoNegative() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        #expect(LowLevelPromptController.seconds(until: now.addingTimeInterval(9.2), now: now) == 10)
        #expect(LowLevelPromptController.seconds(until: now.addingTimeInterval(10), now: now) == 10)
        #expect(LowLevelPromptController.seconds(until: now.addingTimeInterval(-1), now: now) == 0)
        #expect(LowLevelPromptText.countdown(10).contains("10"))
    }

    @Test func aNewConfirmationReplacesTheShownOne() {
        let (services, _, _, posted) = setup()
        let prompt = LowLevelPromptController(services: services, slot: HUDSlot())
        prompt.presentsWindows = false
        let first = pending(services)
        prompt.update(first)
        prompt.update(first)                                              // the same one: nothing new
        #expect(posted.lines.count == 1)
        let second = pending(services, in: 6)
        prompt.update(second)
        #expect(prompt.shown == second && prompt.secondsLeft == 6 && posted.lines.count == 2)
    }
}
