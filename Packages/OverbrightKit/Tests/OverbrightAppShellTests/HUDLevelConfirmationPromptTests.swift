// OverbrightAppShellTests/HUDLevelConfirmationPromptTests.swift — "Keep this level?" (DESIGN.md §6, §12.9; ARCHITECTURE.md §4.9):
// it appears while the engine has a pending confirmation, counts down to the deadline once per second, Keep and Go
// Back answer through the engine, it closes when the engine clears the confirmation (the engine reverts by itself),
// VoiceOver hears it, and it holds the HUD's place. Driven by `ManualTimeSource`; no window is ordered in.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct LevelConfirmationPromptTests {
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

    private func pending(_ services: OverbrightServices, in seconds: TimeInterval = 10) -> LevelConfirmation {
        LevelConfirmation(display: DisplayFixture.Keys.builtIn,
                             previousLevels: [DisplayFixture.Keys.builtIn: LevelPosition(0.5)],
                             deadline: services.time.wallClock.addingTimeInterval(seconds))
    }

    @Test func thePromptAppearsCountsDownAndClosesWhenTheEngineReverts() async throws {
        let (services, boost, time, posted) = setup()
        let slot = HUDSlot()
        let prompt = LevelConfirmationPromptController(services: services, slot: slot)
        prompt.presentsWindows = false
        prompt.start()
        #expect(prompt.shown == nil)
        boost.status.pendingConfirmation = pending(services)
        #expect(await eventually { prompt.shown != nil })
        #expect(prompt.secondsLeft == 10 && slot.occupant == .prompt)
        #expect(posted.lines == [LevelConfirmationPromptText.announcement(10)])
        #expect(posted.lines.first?.contains("10") == true)
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .seconds(3))
        #expect(await eventually { prompt.secondsLeft == 7 })
        boost.status.pendingConfirmation = nil                                // the engine reverted at its deadline
        #expect(await eventually { prompt.shown == nil })
        #expect(slot.occupant == nil && time.sleeperCount == 0)
        prompt.stop()
    }

    @Test func keepAndGoBackAnswerThroughTheEngine() {
        let (services, boost, _, _) = setup()
        let prompt = LevelConfirmationPromptController(services: services, slot: HUDSlot())
        prompt.presentsWindows = false
        boost.status.pendingConfirmation = pending(services)
        prompt.update(boost.status.pendingConfirmation)
        prompt.keep()
        #expect(boost.calls == ["keepLevel"] && prompt.shown == nil)
        boost.status.pendingConfirmation = pending(services, in: 8)
        prompt.update(boost.status.pendingConfirmation)
        #expect(prompt.secondsLeft == 8)
        prompt.goBack()
        #expect(boost.calls == ["keepLevel", "revertLevel"] && prompt.shown == nil)
    }

    @Test func secondsRoundUpAndNeverGoNegative() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        #expect(LevelConfirmationPromptController.seconds(until: now.addingTimeInterval(9.2), now: now) == 10)
        #expect(LevelConfirmationPromptController.seconds(until: now.addingTimeInterval(10), now: now) == 10)
        #expect(LevelConfirmationPromptController.seconds(until: now.addingTimeInterval(-1), now: now) == 0)
        #expect(LevelConfirmationPromptText.countdown(10).contains("10"))
    }

    /// A question on another display replaces the shown one: it is presented (and announced) again.
    @Test func aNewConfirmationReplacesTheShownOne() {
        let (services, _, _, posted) = setup()
        let prompt = LevelConfirmationPromptController(services: services, slot: HUDSlot())
        prompt.presentsWindows = false
        let first = pending(services)
        prompt.update(first)
        prompt.update(first)                                              // the same one: nothing new
        #expect(posted.lines.count == 1)
        let other = LevelConfirmation(display: DisplayFixture.Keys.mpg322ux,
                                         previousLevels: [DisplayFixture.Keys.mpg322ux: .standard],
                                         deadline: services.time.wallClock.addingTimeInterval(6))
        prompt.update(other)
        #expect(prompt.shown == other && prompt.secondsLeft == 6 && posted.lines.count == 2)
    }

    /// A drag on the same display moves its deadline at every step (ARCHITECTURE.md §4.9, the owner's rule of
    /// 2026-10-20): the countdown restarts in place, without presenting or announcing the prompt again, so the slider
    /// keeps the pointer and VoiceOver is not interrupted at every step.
    @Test func aDragRestartsTheCountdownInPlace() async throws {
        let (services, boost, time, posted) = setup()
        let slot = HUDSlot()
        let prompt = LevelConfirmationPromptController(services: services, slot: slot)
        prompt.presentsWindows = false
        prompt.start()
        boost.status.pendingConfirmation = pending(services)
        #expect(await eventually { prompt.shown != nil })
        #expect(posted.lines.count == 1 && slot.occupant == .prompt)
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .seconds(4))
        #expect(await eventually { prompt.secondsLeft == 6 })
        let moved = pending(services)                                     // the next step: 10 s from now again
        boost.status.pendingConfirmation = moved
        #expect(await eventually { prompt.shown == moved })
        #expect(prompt.secondsLeft == 10)
        #expect(posted.lines.count == 1)                                  // not announced again
        #expect(slot.occupant == .prompt)
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .seconds(3))
        #expect(await eventually { prompt.secondsLeft == 7 })            // one countdown, from the new deadline
        #expect(await eventually { time.sleeperCount == 1 })
        prompt.stop()
    }
}
