// OverbrightAppShellTests/StatusItemMenuTests.swift — the status menu's rows, dumped and tested (ARCHITECTURE.md §10.12):
// DESIGN.md §4.3's order and exact English (title case), the banner's sentence and action first, Show Panel first in
// toggle mode, live key equivalents (the current binding, nothing when cleared or in conflict), one submenu per display
// that can boost or dim ("All Displays" while linked), the pause line and Resume, Update Available only when configured;
// the first line names an app in full; the AppKit menu matches the rows, and its items act through the engine with
// source `.menu`.
import AppKit
import Foundation
import Observation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct StatusMenuTests {
    private func services(_ name: String) throws -> OverbrightServices {
        try #require(ScriptedStatuses.services(named: name))
    }

    private func kinds(_ rows: [StatusMenuRow]) -> [String] {
        rows.map { row in
            switch row {
            case .status: "status"
            case .bannerAction: "bannerAction"
            case .showPanel: "showPanel"
            case .separator: "---"
            case .master: "master"
            case .dimAll: "dimAll"
            case .display: "display"
            case .allDisplays: "allDisplays"
            case .pause: "pause"
            case .pausedUntil: "pausedUntil"
            case .resume: "resume"
            case .fillLight: "fillLight"
            case .updateAvailable: "update"
            case .settings: "settings"
            case .help: "help"
            case .quit: "quit"
            }
        }
    }

    @Test func theRowsFollowTheDesignOrder() throws {
        let model = StatusMenuModel.make(services: try services("boosting"))
        #expect(kinds(model.rows) == ["master", "dimAll", "---", "display", "display", "---", "pause", "fillLight", "---",
                                      "settings", "help", "quit"])
        let builtIn = try #require(model.cards[DisplayFixture.Keys.builtIn])
        let dimmed = "  " + (CardMenu.title(of: .dimmed(light: 0.25, isChecked: false), card: builtIn) ?? "")
        #expect(model.dump() == [
            "Turn Off Overbright ⌃⌥⌘B", "Dim All Displays ⌃⌥⌘9", "---",
            "Built-in Retina Display ▸", "  Standard", "  Indoor", "  ✓ Bright Room", "  Sunlight", "  Max", "  ---",
            dimmed, "  ---", "  Don’t Use on This Display",
            "MPG322UX OLED ▸", "  ✓ Standard", "  Bright Room", "  Max", "  ---", dimmed, "  ---",
            "  Use Extra Brightness on This Display",
            "---", "Pause for 1 Hour", "Fill Light", "---", "Settings… ⌘,", "Help", "Quit Overbright ⌘Q",
        ])
    }

    @Test func aBannerPutsItsSentenceAndActionFirst() throws {
        let model = StatusMenuModel.make(services: try services("banner-low-power"))
        #expect(kinds(Array(model.rows.prefix(4))) == ["status", "bannerAction", "---", "master"])
        #expect(model.rows[1] == .bannerAction(.changePowerRules))
        #expect(model.dump()[0].hasSuffix("(disabled)"))
        #expect(model.dump()[1] == "Change Power Rules…")
        let heat = StatusMenuModel.make(services: try services("banner-heat"))
        #expect(kinds(Array(heat.rows.prefix(3))) == ["status", "---", "master"])   // heat has no action
        let paused = StatusMenuModel.make(services: try services("banner-paused"))
        #expect(paused.dump()[1] == "Resume")
        #expect(kinds(paused.rows).contains("pausedUntil") && kinds(paused.rows).contains("resume"))
        #expect(!kinds(paused.rows).contains("pause"))
    }

    /// The first line names the display a stop happened on, and a booster's stop offers Compatibility Mode
    /// (C-PANEL-9, C-PANEL-8).
    @Test func theStatusLineNamesTheDisplayAndABoostersStopOffersCompatibilityMode() throws {
        let services = try services("flicker-stop")
        let boost = try #require(services.boost as? PreviewBoostControl)
        let builtIn = DisplayFixture.Keys.builtIn
        let name = try #require(CardTitles.titles(for: services.boost.status.displays)[builtIn])
        #expect(StatusMenuModel.make(services: services).dump()[0].contains(name))
        let booster = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        boost.status.banner = .attributedDrift(booster, display: builtIn)
        let model = StatusMenuModel.make(services: services)
        #expect(model.dump()[0].contains(name))
        #expect(model.rows[1] == .bannerAction(.useCompatibilityMode(booster)))
        #expect(model.dump()[1] == "Use Compatibility Mode")
        let colorApp = ConflictingApp(entryID: "c", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: "C")
        boost.status.banner = .attributedDrift(colorApp, display: builtIn)
        #expect(StatusMenuModel.make(services: services).rows[1] == .bannerAction(.continueAnyway(colorApp)))
    }

    /// The first line names an app in full, however long: the panel middle-truncates the name and keeps it whole for
    /// its help tag and VoiceOver, but a menu row has no help tag, and the menu sizes itself to its row (C-DESIGN-1).
    @Test func theStatusLineNamesALongAppInFull() throws {
        let services = try services("boosting")
        let boost = try #require(services.boost as? PreviewBoostControl)
        let name = "Display Brightness Controller Professional Edition for Studio Workflows"
        let app = ConflictingApp(entryID: "long", severity: .booster, bundleID: nil, processID: 3, displayName: name)
        boost.status.banner = .conflict(app)
        let banner = BannerModel.make(.conflict(app), displayNames: [:], in: .app)
        #expect(!banner.sentence.contains(name))                               // the panel's sentence truncates it
        let model = StatusMenuModel.make(services: services)
        #expect(model.rows.first == .status(banner.accessibilityLabel))
        #expect(model.dump()[0] == banner.accessibilityLabel + " (disabled)" && model.dump()[0].contains(name))
        let menu = StatusMenuRender.menu(model, services: services) {}
        #expect(menu.items.first?.title.contains(name) == true)
        #expect(menu.items.first?.isEnabled == false)
    }

    @Test func toggleModeStartsWithShowPanel() throws {
        let services = try services("boosting")
        services.settings[GeneralSettings.clickAction] = .toggle
        let rows = StatusMenuModel.make(services: services).rows
        #expect(kinds(Array(rows.prefix(3))) == ["showPanel", "---", "master"])
    }

    @Test func linkedLevelsShowOneAllDisplaysSubmenu() throws {
        let model = StatusMenuModel.make(services: try services("linked"))
        #expect(kinds(model.rows).filter { $0 == "allDisplays" || $0 == "display" } == ["allDisplays"])
        #expect(model.dump().contains("All Displays ▸"))
    }

    @Test func displaysThatCannotBeAdjustedHaveNoSubmenu() throws {
        let model = StatusMenuModel.make(services: try services("why-expanded"))
        #expect(kinds(model.rows).filter { $0 == "display" }.count == 1)       // the Sidecar display is left out
        let nothing = StatusMenuModel.make(services: try services("nothing-capable"))
        #expect(nothing.dump().contains("  No Extra Brightness on This Display (disabled)"))
    }

    @Test func updateAvailableShowsOnlyWhenConfigured() throws {
        let url = try #require(URL(string: "https://example.com/release"))
        let unconfigured = try services("boosting")
        let quiet = try #require(unconfigured.updates as? PreviewUpdateChecking)
        quiet.state = .available(version: "0.2.0", url: url)
        #expect(!kinds(StatusMenuModel.make(services: unconfigured).rows).contains("update"))
        quiet.isConfigured = true
        let rows = StatusMenuModel.make(services: unconfigured).rows
        #expect(rows.contains(.updateAvailable(version: "0.2.0", url: url)))
        #expect(StatusMenuModel.make(services: unconfigured).dump().contains("Update Available: Overbright 0.2.0…"))
    }

    // MARK: Key equivalents

    @Test func keyEquivalentsShowTheLiveBindingOrNothing() throws {
        let services = try services("boosting")
        let shortcuts = try #require(services.shortcuts as? PreviewShortcutCenter)
        let toggle = try #require(MenuKeyEquivalent.of(.toggle, in: shortcuts))
        #expect(toggle.key == "b" && toggle.modifiers == [.control, .option, .command])
        shortcuts.set(.toggle, KeyCombo(keyCode: 9, modifiers: [.command, .shift]))       // rebound to ⇧⌘V
        #expect(MenuKeyEquivalent.of(.toggle, in: shortcuts) == MenuKeyEquivalent(key: "v", modifiers: [.command, .shift]))
        shortcuts.set(.toggle, nil)                                                         // cleared
        #expect(MenuKeyEquivalent.of(.toggle, in: shortcuts) == nil)
        shortcuts.conflicting = [.dimToggle]                                                // another app owns it
        #expect(MenuKeyEquivalent.of(.dimToggle, in: shortcuts) == nil)
        let rows = StatusMenuModel.make(services: services).rows
        #expect(rows.contains(.master(isOn: true, key: nil)) && rows.contains(.dimAll(isDimmed: false, key: nil)))
    }

    /// The space bar shows as the menu's key equivalent in every language: named keys come from the key code, not
    /// from their localized caps ("Пробел", "Leertaste", "空格键") (C-PANEL-19).
    @Test func namedKeysComeFromTheKeyCode() {
        let hyper: KeyCombo.Modifiers = [.control, .option, .command]
        for caps in ["⌃⌥⌘Пробел", "⌃⌥⌘Leertaste", "⌃⌥⌘空格键", "⌃⌥⌘Space"] {
            let center = CapsCenter(combo: KeyCombo(keyCode: 49, modifiers: hyper), caps: caps)
            #expect(MenuKeyEquivalent.of(.toggle, in: center)
                == MenuKeyEquivalent(key: " ", modifiers: [.control, .option, .command]), "\(caps)")
        }
        let f5 = CapsCenter(combo: KeyCombo(keyCode: 0x60, modifiers: hyper), caps: "⌃⌥⌘F5")
        #expect(MenuKeyEquivalent.of(.toggle, in: f5)?.key == String(Character(UnicodeScalar(NSF5FunctionKey) ?? " ")))
        let german = CapsCenter(combo: KeyCombo(keyCode: 27, modifiers: hyper), caps: "⌃⌥⌘ß")
        #expect(MenuKeyEquivalent.of(.toggle, in: german)?.key == "ß")              // a character key: the layout's
    }

    @Test func keyCapsOfAnyLayoutParse() {
        let hyper: KeyCombo.Modifiers = [.control, .option, .command]
        #expect(MenuKeyEquivalent.parse("⌃⌥⌘=", modifiers: hyper)?.key == "=")
        #expect(MenuKeyEquivalent.parse("⌃⌥⌘ß", modifiers: hyper)?.key == "ß")              // German layout
        #expect(MenuKeyEquivalent.parse("⌃⌥⌘Space", modifiers: hyper)?.key == " ")
        #expect(MenuKeyEquivalent.parse("⌃⌥⌘", modifiers: hyper) == nil)
        #expect(MenuKeyEquivalent.parse("⌃⌥⌘F13", modifiers: hyper) == nil)                 // not a menu key here
        #expect(MenuKeyEquivalent(key: "b", modifiers: [.control, .option, .command]).displayText == "⌃⌥⌘B")
    }

    // MARK: AppKit menu

    @Test func theAppKitMenuMatchesTheRowsAndActsThroughTheEngine() throws {
        let services = try services("boosting")
        let model = StatusMenuModel.make(services: services)
        var panelShown = 0
        let menu = StatusMenuRender.menu(model, services: services) { panelShown += 1 }
        #expect(menu.items.count == model.rows.count)
        #expect(menu.items.map { $0.isSeparatorItem ? "---" : $0.title }
            == model.rows.map { StatusMenuRender.title(of: $0) })
        let master = try #require(menu.items.first)
        #expect(master.keyEquivalent == "b" && master.keyEquivalentModifierMask == [.control, .option, .command])
        let display = try #require(menu.items.first { $0.submenu != nil })
        #expect(display.submenu?.items.count == 9)
        let boost = try #require(services.boost as? PreviewBoostControl)
        ActionMenuItem.run(master)
        ActionMenuItem.run(try #require(menu.items.first { $0.title == "Pause for 1 Hour" }))
        ActionMenuItem.run(try #require(menu.items.first { $0.title == "Dim All Displays" }))
        #expect(boost.calls.first == "setOn(false,menu)")
        let pause = try #require(boost.calls.first { $0.hasPrefix("pause(") })
        let expected = services.time.wallClock.addingTimeInterval(3600).timeIntervalSinceReferenceDate
        #expect(pause == "pause(\(expected),menu)")
        #expect(boost.calls.last == "toggleDim(menu)")
        ActionMenuItem.run(try #require(menu.items.first { $0.title == "Quit Overbright" }))
        ActionMenuItem.run(try #require(menu.items.first { $0.title == "Help" }))
        let app = try #require(services.app as? PreviewAppControl)
        #expect(app.calls == ["quit", "showHelp(-)"])
        #expect(panelShown == 0)
    }
}

/// A shortcut center whose one registered combo renders as `caps` (a localized layout's names).
@MainActor @Observable private final class CapsCenter: ShortcutCenter {
    let combo: KeyCombo
    let caps: String

    init(combo: KeyCombo, caps: String) { self.combo = combo; self.caps = caps }

    func state(_ id: ShortcutID) -> ShortcutState { .registered(combo) }
    func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState { state(id) }
    func setRecording(_ recording: Bool) {}
    func displayString(_ id: ShortcutID) -> String? { caps }
}
