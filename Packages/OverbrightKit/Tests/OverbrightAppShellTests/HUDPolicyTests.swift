// OverbrightAppShellTests/HUDPolicyTests.swift — when the HUD shows (DESIGN.md §6, D19; ARCHITECTURE.md §4.9): level
// changes from shortcuts, the Shortcuts app and Focus; "Preparing…" and blocked requests from the icon, a shortcut or
// the Shortcuts app; automation stops, caps and resumes (timer, battery, Low Power, heat, schedule) for 3 s; never for
// the panel, the menu or Settings, never for full-screen, app or game pauses; a change is shown once (by `sequence`);
// General ▸ Show level changes on screen turns it all off; never two: one HUD updated in place, and the
// Keep-this-level prompt takes its place. Driven by `ManualTimeSource`; no window is ordered in.
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct HUDPolicyTests {
    private func change(_ kind: LevelChange.Kind, _ source: ControlSource, sequence: UInt64 = 1) -> LevelChange {
        LevelChange(sequence: sequence, kind: kind, source: source, display: nil)
    }

    private func shows(_ kind: LevelChange.Kind, _ source: ControlSource) -> Bool {
        HUDPolicy.presentation(for: change(kind, source), lastShown: nil, showsHUD: true) != nil
    }

    // MARK: Rules

    @Test func levelChangesShowFromShortcutsIntentsAndFocusOnly() {
        for source in [ControlSource.shortcut, .intent, .focusFilter] { #expect(shows(.level, source), "\(source)") }
        for source in [ControlSource.panel, .menu, .settings, .welcome, .launch, .statusItem, .automation] {
            #expect(!shows(.level, source), "\(source)")
        }
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut), lastShown: nil, showsHUD: true)?.duration
            == .milliseconds(1500))
    }

    @Test func preparingAndBlockedShowForTheIconShortcutsAndIntents() {
        for source in [ControlSource.statusItem, .shortcut, .intent, .focusFilter] {
            #expect(shows(.preparing, source), "\(source)")
            #expect(shows(.blocked(.lowPowerMode), source), "\(source)")
        }
        #expect(!shows(.preparing, .panel) && !shows(.blocked(.battery(percent: 10, threshold: 20)), .menu))
    }

    @Test func automationVariantsShowForThreeSecondsButNeverPausesTheUserCaused() {
        let automations: [LimitReason] = [.battery(percent: 15, threshold: 20), .onBattery, .lowPowerMode, .thermalSerious,
                                          .thermalCritical, .outsideSchedule]
        for reason in automations {
            let presentation = HUDPolicy.presentation(for: change(.automationStopped(reason), .automation),
                                                      lastShown: nil, showsHUD: true)
            #expect(presentation == HUDPolicy.Presentation(duration: .seconds(3), announcement: .alert), "\(reason)")
        }
        for reason in [LimitReason.fullScreenVideo, .fullScreenApp, .pausedApp(bundleID: "com.example.player"), .game,
                       .oledIdle] {
            #expect(!shows(.automationStopped(reason), .automation), "\(reason)")
        }
        #expect(shows(.automationResumed, .automation) && shows(.timerEnded, .automation))
    }

    @Test func theUsersOwnChangesAreNeverRateLimited() {
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut), lastShown: nil, showsHUD: true)?.announcement
            == .feedback)
        #expect(HUDPolicy.presentation(for: change(.level, .intent), lastShown: nil, showsHUD: true)?.announcement
            == .result)
        #expect(HUDPolicy.presentation(for: change(.timerEnded, .automation), lastShown: nil, showsHUD: true)?.announcement
            == .alert)
    }

    @Test func aChangeShowsOnceAndTheSettingTurnsItOff() {
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 4), lastShown: 4, showsHUD: true) == nil)
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 3), lastShown: 4, showsHUD: true) == nil)
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 5), lastShown: 4, showsHUD: true) != nil)
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut), lastShown: nil, showsHUD: false) == nil)
    }

    // MARK: The controller

    private func harness() throws -> (OverbrightServices, PreviewBoostControl, ManualTimeSource, Box) {
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

    /// Design's words stand in for `HUDText.make` (its copy is WP9's): the announcement names the change.
    private static func text(_ change: LevelChange, _ status: BoostStatus) -> HUDText? {
        HUDText(symbol: .sunMax, displayName: nil, value: "v\(change.sequence)", reason: nil,
                announcement: "change \(change.sequence)")
    }

    @Test func theHUDShowsUpdatesInPlaceAndLeavesAfterItsTime() async throws {
        let (services, boost, time, posted) = try harness()
        let slot = HUDSlot()
        let hud = HUDController(services: services, slot: slot, text: Self.text)
        hud.presentsWindows = false
        hud.start()
        boost.setOn(true, source: .shortcut)                               // the preview publishes lastChange 1
        #expect(await eventually { hud.visible != nil })
        #expect(hud.visible?.value == "v1" && slot.occupant == .hud)
        #expect(posted.lines == ["change 1"])
        boost.setOn(false, source: .panel)                                 // the panel: no HUD, no announcement
        #expect(hud.showCount == 1)
        await time.advance(by: .milliseconds(1000))
        boost.setOn(true, source: .shortcut)                               // a new change updates the visible HUD
        #expect(await eventually { hud.visible?.value == "v2" })
        #expect(hud.showCount == 2 && slot.occupant == .hud)
        #expect(await eventually { time.sleeperCount == 1 })               // one timer: the first one was cancelled
        await time.advance(by: .milliseconds(1000))
        #expect(hud.visible != nil)                                        // 1.5 s count from the LAST change
        await time.advance(by: .milliseconds(600))
        #expect(await eventually { hud.visible == nil })
        #expect(slot.occupant == nil)
        hud.stop()
    }

    @Test func theSettingTurnsTheHUDOff() async throws {
        let (services, boost, _, posted) = try harness()
        services.settings[GeneralSettings.showsHUD] = false
        let hud = HUDController(services: services, slot: HUDSlot(), text: Self.text)
        hud.presentsWindows = false
        hud.start()
        boost.setOn(true, source: .intent)
        try await Task.sleep(for: .milliseconds(50))
        #expect(hud.showCount == 0 && posted.lines.isEmpty)
        hud.stop()
    }

    @Test func thePromptTakesTheHUDsPlace() throws {
        let (services, _, _, _) = try harness()
        let slot = HUDSlot()
        let hud = HUDController(services: services, slot: slot, text: Self.text)
        hud.presentsWindows = false
        hud.handle(change(.level, .shortcut, sequence: 1))
        #expect(hud.visible != nil)
        let prompt = LowLevelPromptController(services: services, slot: slot)
        prompt.presentsWindows = false
        prompt.update(LowLevelConfirmation(display: nil, previousLevels: [:],
                                           deadline: services.time.wallClock.addingTimeInterval(10)))
        #expect(hud.visible == nil && slot.occupant == .prompt)            // never two
        hud.handle(change(.level, .shortcut, sequence: 2))
        #expect(hud.visible == nil)                                       // the HUD waits while the prompt shows
        prompt.update(nil)
        hud.handle(change(.level, .shortcut, sequence: 3))
        #expect(hud.visible?.value == "v3")
    }
}

/// Announcements a test collects.
@MainActor final class Box {
    var lines: [String] = []
}
