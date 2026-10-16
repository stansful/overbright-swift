// OverbrightPanelUITests/CardMenuTests.swift — a display's quick levels (the card's context menu and the status menu's
// submenu, DESIGN.md §4.3, §5.4): only the shown presets, the last dim level, Calibrate… and Settings for This
// Display… on the card, Don't Use / Use Extra Brightness, Try Again while failed; and what each row does through the
// engine and the settings, including the OLED notice before extra brightness turns on (§12.4) and the banner actions
// (§12.3).
import Foundation
import OverbrightCore
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
        var asked: [String] = []
        var answer = false
        let commands = PanelCommands(services: services, source: .panel, confirmOLED: { asked.append($0); return answer },
                                     openURL: { _ in })
        let model = try card(services, msi)
        #expect(model.isOLED && !model.boostEnabled)
        CardMenu.perform(.level(.brightRoom, isChecked: false), card: model, commands: commands)
        #expect(asked == ["MPG322UX OLED"])
        #expect(commands.preferences(of: msi).boostEnabled != true)            // Cancel: still off, nothing set
        #expect(boost.calls.isEmpty)
        answer = true
        CardMenu.perform(.level(.brightRoom, isChecked: false), card: model, commands: commands)
        #expect(commands.preferences(of: msi).boostEnabled == true)
        #expect(commands.preferences(of: msi).oledNoticeAcknowledged)
        #expect(boost.calls == ["setExtraBrightness(brightRoom,\(msi.rawValue),panel)"])
        commands.setExtraBrightness(false, for: msi, name: "MPG322UX OLED", isOLED: true)
        commands.setExtraBrightness(true, for: msi, name: "MPG322UX OLED", isOLED: true)
        #expect(asked.count == 2)                                              // acknowledged: never asked again
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
        BannerAction.openFocusSettings.perform(commands, status: services.boost.status)
        #expect(opened == [SettingsLinks.systemFocus].compactMap { $0 })
        BannerAction.resume.perform(commands, status: services.boost.status)
        #expect(boost.calls.last == "resume(panel)")
    }
}
