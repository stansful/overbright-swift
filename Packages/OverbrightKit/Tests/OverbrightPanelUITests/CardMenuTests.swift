// OverbrightPanelUITests/CardMenuTests.swift — a display's quick levels (the card's context menu and the status menu's
// submenu, DESIGN.md §4.3, §5.4): only the shown presets, the last dim level, Calibrate… and Settings for This
// Display… on the card, Don't Use / Use Extra Brightness, Try Again while failed; and what each row does through the
// engine and the settings, including the OLED notice before extra brightness turns on (§12.4), the banner actions
// (§12.3), and no action at all for a booster's stop (§12.2).
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

    /// The gear beside a Safe-limit chip performs `.choosePeak`: Settings ▸ Displays at that display's Limit row.
    @Test func theLimitGearOpensTheLimitRow() throws {
        let (services, _) = try setup("boosting")
        var status = services.boost.status
        let index = try #require(status.displays.firstIndex { $0.key == builtIn })
        status.displays[index].decision?.reasons = [.safeLimit]
        let boost = try #require(services.boost as? PreviewBoostControl)
        boost.status = status
        let model = try card(services, builtIn)
        #expect(DisplayCardView.offersLimitSetting(model, isMasterOn: true))
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { _ in true }, openURL: { _ in })
        commands.perform(.choosePeak, on: model)
        let app = try #require(services.app as? PreviewAppControl)
        #expect(app.calls == ["openSettings(\(SettingsLinks.limit(of: builtIn)))"])
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
        #expect(BannerAction.primary(for: .thermalCritical) == nil)
        #expect(BannerAction.primary(for: .battery(percent: 10, threshold: 20)) == .changePowerRules)
        #expect(BannerAction.primary(for: .flickerStop(display: builtIn)) == .tryAgain(builtIn))
        // A stop caused by a color app offers Continue anyway; a booster's never does (§7.2).
        let s2 = ConflictingApp(entryID: "c", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: "C")
        #expect(BannerAction.primary(for: .attributedDrift(s2, display: builtIn)) == .continueAnyway(s2))
        BannerAction.continueAnyway(s2).perform(commands)
        #expect(boost.calls == ["continueAnyway(\(s2.entryID))"])
        BannerAction.openFocusSettings.perform(commands)
        #expect(opened == [SettingsLinks.systemFocus].compactMap { $0 })
        BannerAction.resume.perform(commands)
        #expect(boost.calls.last == "resume(panel)")
    }

    /// A booster on a card or in the banner (ARCHITECTURE.md §7.2): the banner explains the stop without an action,
    /// the drift chip offers nothing (never Continue anyway), and the reducer keeps blocking that display even with
    /// the app continued.
    @Test func aBoostersStopOffersNoAction() throws {
        let (services, boost) = try setup("boosting")
        let booster = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        #expect(BannerAction.primary(for: .conflict(booster)) == nil)
        #expect(BannerAction.primary(for: .attributedDrift(booster, display: builtIn)) == nil)
        var status = services.boost.status
        let index = try #require(status.displays.firstIndex { $0.key == builtIn })
        status.displays[index].decision?.reasons = [.tripped(.attributedDrift(booster))]
        boost.status = status
        let model = try card(services, builtIn)
        #expect(model.chipReason == .tripped(.attributedDrift(booster)))
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { _ in true }, openURL: { _ in })
        #expect(CardChip.kinds(for: model, isMasterOn: true).isEmpty)
        #expect(CardChip.actions(for: model, isMasterOn: true, commands: commands).isEmpty)
        // The reducer over that display, next to the running booster: blocked, whatever was stored or continued.
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
        #expect(reasons(DisplayPreferences(), continued: []).contains(.conflict(booster)))
        #expect(reasons(DisplayPreferences(), continued: [booster.entryID]).contains(.conflict(booster)))
    }
}

/// The OLED notice's scripted answer and the names it was asked for: a main-actor box, so the test changes the answer
/// after the (Sendable) confirmOLED closure captured it.
@MainActor private final class OLEDNoticeScript {
    var asked: [String] = []
    var answer = false
}
