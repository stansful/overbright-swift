// OverbrightAppShellTests/HUDPolicyTests.swift — when the HUD shows (DESIGN.md §6, D19; ARCHITECTURE.md §4.9): level
// changes from shortcuts, the Shortcuts app, Focus and Back to Standard from anywhere (the Dock menu's included);
// "Preparing…" and blocked requests from the icon, a shortcut or the Shortcuts app, "Preparing…" held until the display
// is ready and then the level reached; automation stops, caps and resumes (timer, battery, Low Power, heat, schedule)
// for 3 s; never for the panel's, the menu's or Settings' own changes, never for full-screen, app or game pauses; a
// change is handled once (by `sequence`); General ▸ Show level changes on screen turns the window off but VoiceOver
// still hears the change, also while the Keep-this-level prompt holds the place; never two: one HUD updated in place.
// A level change shows the level the display is set to as both the value and the bar, even while the engine's status
// still lags behind; a change to every display is shown about the display under the pointer. Driven by
// `ManualTimeSource`; no window is ordered in.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell
@testable import OverbrightPanelUI

@MainActor @Suite struct HUDPolicyTests {
    private func change(_ kind: LevelChange.Kind, _ source: ControlSource, sequence: UInt64 = 1) -> LevelChange {
        LevelChange(sequence: sequence, kind: kind, source: source, display: nil)
    }

    private func shows(_ kind: LevelChange.Kind, _ source: ControlSource) -> Bool {
        HUDPolicy.presentation(for: change(kind, source), lastShown: nil, showsHUD: true) != nil
    }

    // MARK: Rules

    /// The engine publishes `.level` only for a shortcut, an intent, a Focus or Back to Standard (ARCHITECTURE.md §4.9),
    /// so a level change from the menu is the Dock menu's Back to Standard, which shows (C-PANEL-28); Overbright's own
    /// sources never do.
    @Test func levelChangesShowFromShortcutsIntentsFocusAndBackToStandard() {
        for source in [ControlSource.shortcut, .intent, .focusFilter, .menu, .panel, .statusItem] {
            #expect(shows(.level, source), "\(source)")
        }
        for source in [ControlSource.launch, .automation] { #expect(!shows(.level, source), "\(source)") }
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut), lastShown: nil, showsHUD: true)?.duration
            == .milliseconds(1500))
        #expect(HUDPolicy.presentation(for: change(.level, .menu), lastShown: nil, showsHUD: true)?.announcement
            == .feedback)
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

    /// A change is handled once; the setting turns the window off and leaves VoiceOver's announcement (C-PANEL-18).
    @Test func aChangeIsHandledOnceAndTheSettingTurnsOnlyTheWindowOff() {
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 4), lastShown: 4, showsHUD: true) == nil)
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 3), lastShown: 4, showsHUD: true) == nil)
        #expect(HUDPolicy.presentation(for: change(.level, .shortcut, sequence: 5), lastShown: 4, showsHUD: true) != nil)
        let quiet = HUDPolicy.presentation(for: change(.level, .shortcut), lastShown: nil, showsHUD: false)
        #expect(quiet == HUDPolicy.Presentation(duration: .milliseconds(1500), announcement: .feedback, showsWindow: false))
        let timer = HUDPolicy.presentation(for: change(.timerEnded, .automation), lastShown: nil, showsHUD: false)
        #expect(timer?.showsWindow == false && timer?.announcement == .alert)
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

    /// With the setting off the window never shows, yet VoiceOver hears the change: asserted once the change was
    /// observed (the announcement is the positive control), never after a fixed sleep (C-PANEL-32, C-PANEL-18).
    @Test func theSettingTurnsTheWindowOffButNotTheAnnouncement() async throws {
        let (services, boost, _, posted) = try harness()
        services.settings[GeneralSettings.showsHUD] = false
        let hud = HUDController(services: services, slot: HUDSlot(), text: Self.text)
        hud.presentsWindows = false
        hud.start()
        boost.setOn(true, source: .intent)
        #expect(await eventually { hud.lastShown == 1 })
        #expect(posted.lines == ["change 1"])
        #expect(hud.showCount == 0 && hud.visible == nil)
        hud.handle(change(.timerEnded, .automation, sequence: 2))           // synchronous: nothing to wait for
        #expect(hud.showCount == 0 && hud.lastShown == 2)
        hud.stop()
    }

    /// While the Keep-this-level prompt holds the place, a change is still announced (C-PANEL-18).
    @Test func aChangeUnderThePromptIsStillAnnounced() throws {
        let (services, _, _, posted) = try harness()
        let slot = HUDSlot()
        let hud = HUDController(services: services, slot: slot, text: Self.text)
        hud.presentsWindows = false
        let prompt = LowLevelPromptController(services: services, slot: slot)
        prompt.presentsWindows = false
        prompt.update(LowLevelConfirmation(display: nil, previousLevels: [:],
                                           deadline: services.time.wallClock.addingTimeInterval(10)))
        hud.handle(change(.level, .shortcut, sequence: 1))
        #expect(hud.visible == nil && slot.occupant == .prompt)
        #expect(posted.lines.contains("change 1"))
        prompt.update(nil)
    }

    /// The HUD's value is the level the display is set to, the same as its bar, while the engine's status still lags:
    /// after a shortcut dims to 50 %, the readout still says Standard and the HUD says "Dimmed · 50 %" (C-PANEL-5).
    @Test func aShortcutLevelShowsItsTargetWhileTheStatusLags() throws {
        let services = try #require(ScriptedStatuses.services(named: "standard"))
        let key = DisplayFixture.Keys.builtIn
        let dim = LevelMapping.position(forDimLight: 0.5)
        var all = services.settings[DisplaySettings.perDisplay]
        var preferences = all[key] ?? DisplayPreferences()
        preferences.level = dim
        all[key] = preferences
        services.settings[DisplaySettings.perDisplay] = all
        let status = services.boost.status                                 // still Standard on screen
        #expect(status.displays.first { $0.key == key }?.appliedGain == 1)
        let shortcut = LevelChange(sequence: 1, kind: .level, source: .shortcut, display: key)
        let text = try #require(HUDContent.text(for: shortcut, status: status, on: key, services: services))
        let card = DisplayCardModel(status: try #require(status.displays.first { $0.key == key }), isMasterOn: true,
                                    services: services)
        let expected = ValueText.make(ReadoutValues(state: .dim, appliedGain: 0.5, requestedGain: nil, nits: nil, preset: nil,
                                                    isEstimate: card.readout.isEstimate, dimPercent: 50))
        #expect(text.value == expected.text && text.symbol == .sunMin && text.reason == nil)
        #expect(HUDContent.level(of: key, status: status, services: services) == dim)
    }

    /// A turn-on's "Preparing…" stays until the display is ready, then shows the level reached for 1.5 s (C-PANEL-5).
    @Test func preparingStaysUntilReadyThenShowsTheLevelReached() async throws {
        let services = try #require(ScriptedStatuses.services(named: "preparing"))
        let boost = try #require(services.boost as? PreviewBoostControl)
        let time = try #require(services.time as? ManualTimeSource)
        let hud = HUDController(services: services)
        hud.presentsWindows = false
        hud.handle(LevelChange(sequence: 7, kind: .preparing, source: .shortcut, display: nil))
        #expect(hud.visible?.reason != nil && hud.visible?.value == nil)       // the reason layout, not the value slot
        await time.advance(by: .seconds(2))
        #expect(hud.visible?.reason != nil)                                   // still preparing: still up
        var ready = boost.status
        ready.displays = ready.displays.map { display in
            var display = display
            if case .arming = display.phase { display.phase = .boosted; display.appliedGain = 1.29 }
            return display
        }
        boost.status = ready
        #expect(await eventually { hud.visible?.value != nil })                // the level reached
        #expect(hud.visible?.reason == nil)
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .milliseconds(1600))
        #expect(await eventually { hud.visible == nil })
    }

    /// "Preparing…" gives up waiting after 3 s and shows the level then.
    @Test func preparingWaitsAtMostThreeSeconds() async throws {
        let services = try #require(ScriptedStatuses.services(named: "preparing"))
        let time = try #require(services.time as? ManualTimeSource)
        let hud = HUDController(services: services)
        hud.presentsWindows = false
        hud.handle(LevelChange(sequence: 3, kind: .preparing, source: .statusItem, display: nil))
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: .seconds(3))
        #expect(await eventually { hud.visible?.value != nil })
    }

    /// A change to every display is shown about the display under the pointer; one of a display about that display
    /// (C-PANEL-25).
    @Test func aChangeToEveryDisplayIsShownAboutTheDisplayUnderThePointer() throws {
        let status = try #require(ScriptedStatuses.status(named: "hud-two-displays"))
        let builtIn = DisplayFixture.Keys.builtIn
        let msi = DisplayFixture.Keys.mpg322ux
        let all = LevelChange(sequence: 1, kind: .level, source: .shortcut, display: nil)
        #expect(HUDContent.shownDisplay(for: all, underPointer: msi, status: status) == msi)
        #expect(HUDContent.shownDisplay(for: all, underPointer: nil, status: status) == builtIn)
        let one = LevelChange(sequence: 1, kind: .level, source: .shortcut, display: builtIn)
        #expect(HUDContent.shownDisplay(for: one, underPointer: msi, status: status) == builtIn)
        let facts = [ScriptedParts.builtIn, ScriptedParts.msi]
        let screens: [(id: CGDirectDisplayID?, frame: CGRect, visibleFrame: CGRect)] = [
            (ScriptedParts.builtIn.ref.id, CGRect(x: 0, y: 0, width: 1512, height: 982), .zero),
            (ScriptedParts.msi.ref.id, CGRect(x: 1512, y: 0, width: 3840, height: 2160), .zero),
        ]
        #expect(HUDPlacement.display(at: CGPoint(x: 2000, y: 400), screens: screens, displays: facts) == msi)
        #expect(HUDPlacement.display(at: CGPoint(x: 100, y: 400), screens: screens, displays: facts) == builtIn)
        #expect(HUDPlacement.display(at: CGPoint(x: -100, y: 400), screens: screens, displays: facts) == nil)
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
