// OverbrightPanelUITests/CardMenuTests.swift — a display's quick levels (the card's context menu and the status menu's
// submenu, DESIGN.md §4.3, §5.4): only the shown presets, the last dim level, Calibrate… and Settings for This
// Display… on the card, Don't Use / Use Extra Brightness, Try Again while failed; and what each row does through the
// engine and the settings, including the OLED notice before extra brightness turns on (§12.4), the banner actions
// (§12.3) and the chip's Compatibility mode for a booster's stop (§12.2).
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct CardMenuTests {
    private let builtIn = DisplayFixture.Keys.builtIn
    private let msi = DisplayFixture.Keys.mpg322ux

    private func setup(_ name: String) throws -> (OverbrightServices, PreviewBoostControl) {
        let services = try #require(ScriptedStatuses.services(named: name))
        let boost = try #require(services.boost as? PreviewBoostControl)
        return (services, boost)
    }

    private func card(_ services: OverbrightServices, _ key: DisplayKey) throws -> DisplayCardModel {
        let status = try #require(services.boost.status.displays.first { $0.key == key })
        return DisplayCardModel(status: status, isMasterOn: services.boost.status.isOn, services: services)
    }

    @Test func theRowsListOnlyTheShownPresets() throws {
        let (services, _) = try setup("boosting")
        let model = try card(services, builtIn)
        let menu = CardMenu.items(for: model, lastDimLight: 0.25, contextMenu: false)
        #expect(menu == [.level(.standard, isChecked: false), .level(.indoor, isChecked: false),
                         .level(.brightRoom, isChecked: true), .level(.sunlight, isChecked: false),
                         .level(.max, isChecked: false), .separator, .dimmed(light: 0.25, isChecked: false), .separator,
                         .extraBrightness(turnOn: false)])
        let context = CardMenu.items(for: model, lastDimLight: 0.25, contextMenu: true)
        #expect(context.suffix(3) == [.calibrate, .settingsForDisplay, .extraBrightness(turnOn: false)])
        let oled = try card(try #require(ScriptedStatuses.services(named: "small-gain")), msi)
        let presets = CardMenu.items(for: oled, lastDimLight: 0.25, contextMenu: false).compactMap { item -> LevelPreset? in
            if case .level(let preset, _) = item { return preset }
            return nil
        }
        #expect(presets == [.standard, .brightRoom, .max])                     // Indoor and Sunlight are hidden
    }

    @Test func aDisplayThatCannotBoostKeepsStandardAndDimmed() throws {
        let (services, _) = try setup("nothing-capable")
        let menu = CardMenu.items(for: try card(services, msi), lastDimLight: 0.25, contextMenu: false)
        #expect(menu == [.level(.standard, isChecked: true), .noExtraBrightness, .separator,
                         .dimmed(light: 0.25, isChecked: false)])
    }

    @Test func theDimRowIsCheckedAtTheLastDimLevelAndTryAgainShowsWhileFailed() throws {
        let (services, _) = try setup("dimmed")
        let dimmed = CardMenu.items(for: try card(services, builtIn), lastDimLight: 0.25, contextMenu: false)
        #expect(dimmed.contains(.dimmed(light: 0.25, isChecked: true)))
        #expect(dimmed.contains(.level(.standard, isChecked: false)))
        let (failedServices, _) = try setup("no-extra-range")
        let failed = CardMenu.items(for: try card(failedServices, builtIn), lastDimLight: 0.25, contextMenu: true)
        #expect(failed.last == .tryAgain)
    }

    @Test func rowsActThroughTheEngine() throws {
        let (services, boost) = try setup("boosting")
        let model = try card(services, builtIn)
        let commands = PanelCommands(services: services, source: .menu, confirmOLED: { _ in true }, openURL: { _ in })
        CardMenu.perform(.level(.sunlight, isChecked: false), card: model, commands: commands)
        CardMenu.perform(.dimmed(light: 0.25, isChecked: false), card: model, commands: commands)
        CardMenu.perform(.level(.standard, isChecked: false), card: model, commands: commands)
        CardMenu.perform(.tryAgain, card: model, commands: commands)
        let key = builtIn.rawValue
        #expect(boost.calls == ["setExtraBrightness(sunlight,\(key),menu)", "setDimLight(0.25,\(key),menu)",
                                "setLevel(0.0,\(key),menu)", "retry(\(key))"])
        CardMenu.perform(.settingsForDisplay, card: model, commands: commands)
        CardMenu.perform(.calibrate, card: model, commands: commands)
        let app = try #require(services.app as? PreviewAppControl)
        #expect(app.calls == ["openSettings(\(SettingsLinks.display(builtIn)))", "showCalibration(\(key))"])
    }

    @Test func linkedLevelsActOnEveryDisplay() throws {
        let (services, boost) = try setup("linked")
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { _ in true }, openURL: { _ in })
        CardMenu.perform(.level(.max, isChecked: false), card: try card(services, msi), commands: commands)
        #expect(boost.calls == ["setExtraBrightness(max,all,panel)"])
    }

    @Test func turningExtraBrightnessOnForAnOLEDAsksFirstOnce() throws {
        let (services, boost) = try setup("extra-brightness-off")
        let notice = OLEDNoticeScript()
        let commands = PanelCommands(services: services, source: .panel,
                                     confirmOLED: { notice.asked.append($0); return notice.answer }, openURL: { _ in })
        let model = try card(services, msi)
        #expect(model.isOLED && !model.boostEnabled)
        CardMenu.perform(.level(.brightRoom, isChecked: false), card: model, commands: commands)
        #expect(notice.asked == ["MPG322UX OLED"])
        #expect(commands.preferences(of: msi).boostEnabled != true)            // Cancel: still off, nothing set
        #expect(boost.calls.isEmpty)
        notice.answer = true
        CardMenu.perform(.level(.brightRoom, isChecked: false), card: model, commands: commands)
        #expect(commands.preferences(of: msi).boostEnabled == true)
        #expect(commands.preferences(of: msi).oledNoticeAcknowledged)
        #expect(boost.calls == ["setExtraBrightness(brightRoom,\(msi.rawValue),panel)"])
        commands.setExtraBrightness(false, for: msi, name: "MPG322UX OLED", isOLED: true)
        commands.setExtraBrightness(true, for: msi, name: "MPG322UX OLED", isOLED: true)
        #expect(notice.asked.count == 2)                                       // acknowledged: never asked again
    }

    @Test func dontUseReturnsADimmedDisplayToStandard() throws {
        let (services, boost) = try setup("dimmed")
        let commands = PanelCommands(services: services, source: .menu, confirmOLED: { _ in true }, openURL: { _ in })
        commands.setExtraBrightness(false, for: builtIn, name: "Built-in", isOLED: false)
        #expect(commands.preferences(of: builtIn).boostEnabled == false)
        #expect(boost.calls == ["setLevel(0.0,\(builtIn.rawValue),menu)"])
    }

    @Test func bannerActionsDoWhatTheirButtonsSay() throws {
        let (services, boost) = try setup("conflict-booster")
        var opened: [URL] = []
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { _ in true },
                                     openURL: { opened.append($0) })
        let banner = try #require(services.boost.status.banner)
        let action = try #require(BannerAction.primary(for: banner))
        guard case .useCompatibilityMode(let app) = action else { Issue.record("S1 offers Compatibility mode"); return }
        action.perform(commands, status: services.boost.status)
        #expect(commands.preferences(of: builtIn).mechanism == .overlay)
        #expect(boost.calls == ["continueAnyway(\(app.entryID))"])
        #expect(BannerAction.primary(for: .thermalCritical) == nil)
        #expect(BannerAction.primary(for: .battery(percent: 10, threshold: 20)) == .changePowerRules)
        #expect(BannerAction.primary(for: .flickerStop(display: builtIn)) == .tryAgain(builtIn))
        // A stop caused by a booster offers Compatibility mode, never Continue anyway; a color app's offers it (§7.2).
        let s1 = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        let s2 = ConflictingApp(entryID: "c", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: "C")
        #expect(BannerAction.primary(for: .attributedDrift(s1, display: builtIn)) == .useCompatibilityMode(s1))
        #expect(BannerAction.primary(for: .attributedDrift(s2, display: builtIn)) == .continueAnyway(s2))
        BannerAction.openFocusSettings.perform(commands, status: services.boost.status)
        #expect(opened == [SettingsLinks.systemFocus].compactMap { $0 })
        BannerAction.resume.perform(commands, status: services.boost.status)
        #expect(boost.calls.last == "resume(panel)")
    }

    /// A booster's drift stop on a card (C-PANEL-8): the chip offers "Use Compatibility mode", never Continue anyway,
    /// and performing it both switches that display to the overlay and continues the app, the two things the reducer's
    /// S1 rule needs to let the display through (ARCHITECTURE.md §7.2); what the commands did is fed back into it.
    @Test func theChipsCompatibilityModeLetsABoostersDisplayThrough() throws {
        let (services, boost) = try setup("boosting")
        let booster = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        var status = services.boost.status
        let index = try #require(status.displays.firstIndex { $0.key == builtIn })
        status.displays[index].decision?.reasons = [.tripped(.attributedDrift(booster))]
        boost.status = status
        let model = try card(services, builtIn)
        #expect(model.chipReason == .tripped(.attributedDrift(booster)))
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { _ in true }, openURL: { _ in })
        let actions = CardChip.actions(for: model, isMasterOn: true, commands: commands)
        #expect(actions.map(\.title) == [CardAction.useCompatibilityMode.title])
        try #require(actions.count == 1)
        actions[0].perform()
        #expect(boost.calls == ["continueAnyway(\(booster.entryID))"])
        #expect(commands.preferences(of: builtIn).mechanism == .overlay)
        // The reducer over that display, next to the running booster: blocked before, let through after.
        let display = DisplayFixture.builtinXDRLidOpen.displays[0]
        try #require(display.key == builtIn)
        func reasons(_ preferences: DisplayPreferences, continued: Set<String>) -> [LimitReason] {
            let reading = HeadroomReading(display: display.facts.ref.id, current: display.headroom.grant,
                                          potential: display.headroom.potential, reference: display.headroom.reference,
                                          time: MonotonicInstant(sinceOrigin: .zero))
            let power = PowerState(source: .adapter, batteryPercent: 90, isLowPowerMode: false)
            let input = PolicyInput(isMasterOn: true, pausedUntil: nil,
                                    now: Date(timeIntervalSinceReferenceDate: 800_000_000), minuteOfDay: 600,
                                    machine: DisplayFixture.ownerMachine, settings: PolicySettings(),
                                    system: SystemSnapshot(power: power, conflicts: [booster]),
                                    displays: [DisplayPolicyInput(facts: display.facts, preferences: preferences,
                                                                  feedback: EngineFeedback(lastReading: reading),
                                                                  sdrWhite: nil)],
                                    continuedEntryIDs: continued)
            return BoostPolicy.reduce(input).displays[builtIn]?.reasons ?? []
        }
        let continued = Set(boost.calls.compactMap { call -> String? in
            call.hasPrefix("continueAnyway(") ? String(call.dropFirst("continueAnyway(".count).dropLast()) : nil
        })
        #expect(reasons(DisplayPreferences(), continued: []).contains(.conflict(booster)))
        #expect(!reasons(commands.preferences(of: builtIn), continued: continued).contains(.conflict(booster)))
        #expect(reasons(DisplayPreferences(), continued: continued).contains(.conflict(booster)))   // continue alone
    }
}

/// The OLED notice's scripted answer and the names it was asked for: a main-actor box, so the test changes the answer
/// after the (Sendable) confirmOLED closure captured it.
@MainActor private final class OLEDNoticeScript {
    var asked: [String] = []
    var answer = false
}
