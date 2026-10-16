// OverbrightAppShellTests/QAScriptedStateTests.swift — `--qa-state <name>` as the app renders it (ARCHITECTURE.md §8.5,
// DESIGN.md §5.13): the state's status drives `PreviewBoostControl`, its settings go into the run's QA suite, Fill Light
// and the "Why?" row show as the state says. The QA check: for every state of the gallery, every card's thumb (its
// stored level) is the level its readout names, a boosting readout has its thumb in the boost half with extra brightness
// on, a dimmed one in the dim half at that light, and the HUD's bar agrees. Before the fix the app got the status
// alone: about 20 of the 57 states contradicted themselves ("Dimmed · 25 %" with the thumb at Bright room, a boosting
// MSI drawn as switched off, no link glyph, no Fill Light card, Why collapsed, HUD bars at Bright room).
#if DEBUG
import Foundation
import OverbrightCore
import OverbrightPanelUI
import OverbrightPolicy
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct QAScriptedStateTests {
    /// What `AppDelegate.makeShell` builds for `--qa-state <name>` over the simulated ports, into `settings` (the
    /// run's QA suite).
    private func launch(_ name: String, settings: SettingsStore = SettingsStore(defaults: InMemoryDefaults()))
        throws -> (Shell, QAHooks.ScriptedState) {
        let context = TestShell.context(settings: settings)
        let arguments = LaunchArguments(["Overbright", "--qa-simulate", "builtin-xdr-lid-open", "--qa-state", name])
        let state = try #require(QAHooks.scriptedState(arguments, settings: context.settings, qaSuite: "qa"), "\(name)")
        let shell = CompositionRoot.makeShell(context, ports: TestShell.ports(context: context),
                                              scriptedStatus: state.status, scriptedFillLightOn: state.fillLightOn)
        return (shell, state)
    }

    @Test func everyReadoutMatchesItsThumb() throws {
        #expect(ScriptedStatuses.names.count >= 57)
        var cards = 0
        for name in ScriptedStatuses.names {
            let (shell, _) = try launch(name)
            let services = shell.services
            let status = services.boost.status
            for display in status.displays {
                let card = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services)
                let label = "\(name) · \(display.key.rawValue.suffix(4))"
                cards += 1
                if let level = display.decision?.level {
                    #expect(card.level == level, "\(label): thumb at \(card.level.value), readout at \(level.value)")
                }
                if let preset = card.readout.preset {
                    #expect(card.level == preset.position, "\(label): the readout names \(preset), the thumb is elsewhere")
                }
                switch card.readout.state {
                case .boost:
                    #expect(card.level.isBoost, "\(label): boosting with the thumb at \(card.level.value)")
                    #expect(card.boostEnabled && card.boostHalf != .switchedOff, "\(label): boosting, drawn switched off")
                case .dim:
                    let percent = try #require(card.readout.dimPercent)
                    #expect(card.level.isDim, "\(label): dimmed with the thumb at \(card.level.value)")
                    #expect(abs(LevelMapping.dimLight(for: card.level) * 100 - Double(percent)) < 1,
                            "\(label): \(percent) % with the thumb at \(LevelMapping.dimLight(for: card.level))")
                case .off, .standard, .preparing:
                    break
                }
                if status.isOn, card.readout.state != .off {
                    let bar = HUDController.level(of: display.key, status: status, settings: services.settings)
                    #expect(bar == card.level, "\(label): the HUD's bar at \(bar.value), the thumb at \(card.level.value)")
                }
            }
        }
        #expect(cards >= ScriptedStatuses.names.count)
    }

    /// The states the review saw contradict themselves, named: the dimmed thumb, the linked glyph, the MSI's switch,
    /// the OLED's Max, the Fill Light card, the expanded "Why?" row and the HUD's bars.
    @Test func theNamedStatesShowWhatTheySay() throws {
        let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts.ref.key
        let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts.ref.key
        func card(_ name: String, _ key: DisplayKey) throws -> DisplayCardModel {
            let services = try launch(name).0.services
            let status = try #require(services.boost.status.displays.first { $0.key == key })
            return DisplayCardModel(status: status, isMasterOn: services.boost.status.isOn, services: services)
        }
        #expect(try card("dimmed", builtIn).level == LevelMapping.position(forDimLight: 0.25))
        #expect(try card("linked", builtIn).isLinked && card("linked", msi).isLinked)
        #expect(try card("linked", msi).boostHalf == .active)
        #expect(try card("safe-limit-oled", msi).level == LevelPreset.max.position)
        #expect(try card("hud-standard", builtIn).level == .standard)
        #expect(try launch("fill-light-card").0.services.fillLight.isOn)
        #expect(try !launch("boosting").0.services.fillLight.isOn)
        #expect(try launch("why-expanded").1.expandsWhy && !launch("boosting").1.expandsWhy)
        #expect(try launch("calibration-tip").0.services.settings[OnboardingSettings.calibrationTipShown] == false)
        let boosting = try launch("boosting").0.services.settings
        #expect(boosting[DisplaySettings.perDisplay][builtIn]?.calibration != nil)
    }

    /// A QA suite keeps its values between runs: each state starts from the gallery's defaults, so the state shown
    /// last does not leak into the next (linked levels, a calibration record, the auto-off timer, the tip).
    @Test func aStateDoesNotInheritThePreviousRunsSettings() throws {
        let suite = SettingsStore(defaults: InMemoryDefaults())
        _ = try launch("boosting", settings: suite)
        _ = try launch("calibration-tip", settings: suite)
        _ = try launch("linked", settings: suite)
        #expect(suite[DisplaySettings.linkLevels])
        _ = try launch("dimmed", settings: suite)
        #expect(!suite[DisplaySettings.linkLevels])
        #expect(suite[AutomationSettings.autoOffMinutes] == AutomationSettings.autoOffMinutes.defaultValue)
        #expect(suite[OnboardingSettings.calibrationTipShown])
        #expect(suite[DisplaySettings.perDisplay].values.allSatisfy { $0.calibration == nil })
    }

    /// Without a QA suite nothing is written (the app gives `--qa-state` in-memory settings then, `QAHooks.defaults`);
    /// an unknown name is no state.
    @Test func noSuiteWritesNothingAndAnUnknownNameIsNoState() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let arguments = LaunchArguments(["Overbright", "--qa-state", "dimmed"])
        #expect(QAHooks.scriptedState(arguments, settings: settings, qaSuite: nil) != nil)
        #expect(settings.storedKeyIDs().isEmpty)
        #expect(QAHooks.scriptedState(LaunchArguments(["Overbright", "--qa-state", "nope"]), settings: settings,
                                      qaSuite: "qa") == nil)
        #expect(QAHooks.scriptedState(LaunchArguments(["Overbright"]), settings: settings, qaSuite: "qa") == nil)
    }
}
#endif
