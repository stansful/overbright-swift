// OverbrightDesignTests/HUDTextTests.swift — DESIGN.md §6 and §12.9: when the HUD shows (shortcuts, the Shortcuts app,
// a Focus; never the panel, the menu or Settings; never the user's own full-screen, app or game pauses), its reason
// lines, glyphs, the display name with two displays and the announcement.
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightDesign

@Suite struct HUDTextTests {
    nonisolated static let builtIn = DisplayKey(rawValue: "A"), external = DisplayKey(rawValue: "B")

    private func display(_ key: DisplayKey, _ name: String, phase: EnginePhase = .boosted, gain: Double = 1.29) -> DisplayStatus {
        DisplayStatus(key: key, name: name, phase: phase, decision: nil, appliedGain: gain, appliedFactor: 1, mechanism: .table,
                      strategy: nil, lastReading: nil, sdrWhite: nil)
    }

    private func status(isOn: Bool = true, two: Bool = false) -> BoostStatus {
        var displays = [display(Self.builtIn, "Built-in Display")]
        if two { displays.append(display(Self.external, "Studio Display")) }
        return BoostStatus(isOn: isOn, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: displays, banner: nil,
                           symbol: isOn ? .on : .off)
    }

    private func hud(_ kind: LevelChange.Kind, source: ControlSource = .automation, display: DisplayKey? = nil,
                     status: BoostStatus? = nil) -> HUDText? {
        HUDText.make(LevelChange(sequence: 1, kind: kind, source: source, display: display), status: status ?? self.status(),
                     on: nil, in: english)
    }

    /// Changes in the panel, the menu and Settings show their own state: no HUD.
    @Test func levelChangesShowOnlyFromShortcutsIntentsAndFocus() {
        for source in [ControlSource.shortcut, .intent, .focusFilter] {
            #expect(hud(.level, source: source) != nil, "\(source)")
        }
        for source in [ControlSource.panel, .menu, .settings, .welcome, .statusItem, .launch] {
            #expect(hud(.level, source: source) == nil, "\(source)")
        }
    }

    @Test func preparingShowsForATurnOnFromTheIconAShortcutOrTheShortcutsApp() {
        #expect(hud(.preparing, source: .statusItem)?.reason == "Preparing…")
        #expect(hud(.preparing, source: .statusItem)?.symbol == .hourglass)
        #expect(hud(.preparing, source: .shortcut) != nil)
        #expect(hud(.preparing, source: .panel) == nil)
    }

    /// The reason lines of DESIGN.md §12.9.
    @Test func theReasonLines() {
        let rows: [(LevelChange.Kind, String, OverbrightSymbol)] = [
            (.automationStopped(.focusOff), "Off for this Focus", .pauseFill),
            (.automationStopped(.battery(percent: 12, threshold: 20)), "Paused: battery below 20%", .pauseFill),
            (.automationStopped(.onBattery), "Paused: on battery", .pauseFill),
            (.automationStopped(.lowPowerMode), "Paused: Low Power Mode", .pauseFill),
            (.automationStopped(.thermalCritical), "Paused: Mac is hot", .thermometerMedium),
            (.automationStopped(.thermalSerious), "Limited: Mac is warm", .thermometerMedium),
            (.automationStopped(.outsideSchedule), "Paused: outside set hours", .pauseFill),
            (.timerEnded, "Off: timer ended", .sunMax),
            (.automationResumed, "Extra brightness is back", .sunMaxFill),
        ]
        for (kind, line, symbol) in rows {
            let text = hud(kind)
            #expect(text?.reason == line, "\(kind)")
            #expect(text?.value == nil, "\(kind): a reason replaces the bar")
            #expect(text?.symbol == symbol, "\(kind)")
            #expect(text?.announcement == line, "\(kind)")
        }
        let german = CopyLanguage(bundle: english.bundle, locale: Locale(identifier: "de_DE"), timeZone: .gmt)
        let paused = HUDText.make(LevelChange(sequence: 1, kind: .automationStopped(.userPaused(until: BannerModelTests.twentyPastTwo)),
                                              source: .automation, display: nil), status: status(), on: nil, in: german)
        #expect(paused?.reason == "Paused until 14:20")
    }

    /// The user caused full-screen, app and game pauses: an automation never announces them.
    @Test func userCausedPausesAreNeverShown() {
        for reason in [LimitReason.fullScreenVideo, .fullScreenApp, .pausedApp(bundleID: "com.example.player"), .game, .oledIdle] {
            #expect(hud(.automationStopped(reason)) == nil, "\(reason)")
        }
        #expect(hud(.automationStopped(.masterOff)) == nil)
        #expect(hud(.automationStopped(.shielded)) == nil)
    }

    /// A blocked request names the guard: global guards with their HUD line, per-display reasons with their chip.
    @Test func aBlockedRequestNamesTheGuard() {
        #expect(hud(.blocked(.lowPowerMode), source: .shortcut)?.reason == "Paused: Low Power Mode")
        #expect(hud(.blocked(.boostNotEnabled), source: .intent)?.reason == "Extra brightness off")
        #expect(hud(.blocked(.fullScreenVideo), source: .shortcut)?.reason == "Paused: video")
        #expect(hud(.blocked(.lowPowerMode), source: .panel) == nil, "the panel shows its own state")
        #expect(hud(.blocked(.lowPowerMode), source: .shortcut)?.symbol == .pauseFill)
    }

    /// Off shows "Off"; a level shows the readout's own value text, byte for byte (DESIGN.md §1 principle 4).
    @Test func levelValuesAreTheReadoutsText() throws {
        let off = try #require(hud(.level, source: .shortcut, status: status(isOn: false)))
        #expect(off.value == "Off" && off.symbol == .sunMax && off.reason == nil)
        let on = try #require(hud(.level, source: .shortcut, display: Self.builtIn))
        let expected = ValueText.make(Readout.values(for: status().displays[0], isMasterOn: true), in: english)
        #expect(on.value == expected.text)
        #expect(on.announcement == expected.accessibilityText)
    }

    /// The display name shows only with two or more displays.
    @Test func theNameShowsWithTwoDisplays() {
        #expect(hud(.automationResumed, display: Self.builtIn)?.displayName == nil)
        let two = hud(.automationResumed, display: Self.external, status: status(two: true))
        #expect(two?.displayName == "Studio Display")
        let all = HUDText.make(LevelChange(sequence: 1, kind: .automationResumed, source: .automation, display: nil),
                               status: status(two: true), on: Self.external, in: english)
        #expect(all?.displayName == "Studio Display", "a change to every display shows on the display under the pointer")
    }
}
