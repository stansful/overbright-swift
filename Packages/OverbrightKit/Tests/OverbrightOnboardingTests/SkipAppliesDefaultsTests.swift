// OverbrightOnboardingTests/SkipAppliesDefaultsTests.swift — what Skip, the close button, Done and Quit leave behind
// (DESIGN.md §8: "Skip (and closing the window) applies every default, including the login item ('Open Overbright,
// keep it off', registered with SMAppService.mainApp). Done applies the choices of step 3."; §12.4; D16). On a first
// run every setting Welcome asks about is at its default, so a Skip leaves exactly the defaults and registers the
// default login item, whatever was picked before it (step 2's switches included); Done writes the picks and applies
// the chosen login behaviour; Quit Overbright applies nothing. Welcome opened again from Settings ▸ About shows the
// stored settings; a Skip there registers the default login item, as DESIGN.md §8 reads (WP14 C-ONBOARD-5), and resets
// nothing else the person set in Settings (Reset All is the one reset, with its own confirmation and Undo).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightOnboarding

/// The settings Welcome's step 3 and step 5 choose.
@MainActor private func expectEveryWelcomeSettingIsDefault(_ settings: SettingsStore,
                                                            sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(settings.isDefault(AutomationSettings.batteryGuard), sourceLocation: sourceLocation)
    #expect(settings.isDefault(AutomationSettings.batteryThreshold), sourceLocation: sourceLocation)
    #expect(settings.isDefault(AutomationSettings.pauseInLowPowerMode), sourceLocation: sourceLocation)
    #expect(settings.isDefault(AutomationSettings.pauseForFullScreenVideo), sourceLocation: sourceLocation)
    #expect(settings.isDefault(UpdateSettings.automatic), sourceLocation: sourceLocation)
    #expect(settings[GeneralSettings.launchBehavior] == .launchOnly, sourceLocation: sourceLocation)
}

/// Every choice of step 3 and step 5 away from its default.
@MainActor private func pickEverythingElse(_ choices: WelcomeChoices, _ settings: SettingsStore) {
    choices.launchBehavior = .dontLaunch
    choices.setPausesOnBattery(false, in: settings)
    choices.batteryThreshold = 50
    choices.pauseInLowPowerMode = false
    choices.pauseForFullScreenVideo = false
    choices.checksForUpdates = true
}

@MainActor @Suite struct SkipAppliesDefaultsTests {
    /// The defaults the steps show on a first run are the settings' defaults (DESIGN.md §7.3, §7.5, §8).
    @Test func aFirstRunShowsTheDefaults() throws {
        let harness = try WelcomeHarness(step: .defaults, updatesConfigured: true)
        let choices = harness.session.choices, settings = harness.services.settings
        #expect(choices.launchBehavior(in: settings) == .launchOnly)                     // "Open, keep off"
        #expect(choices.pausesOnBattery(in: settings) && choices.batteryThreshold(in: settings) == 20)
        #expect(choices.pauseInLowPowerMode(in: settings) && choices.pauseForFullScreenVideo(in: settings))
        #expect(!choices.checksForUpdates(in: settings))
    }

    /// Esc, then Skip: whatever was picked, every Welcome setting stays at its default, the default login item is
    /// registered, and Welcome is recorded as finished.
    @Test func skipLeavesEveryDefaultAndRegistersTheLoginItem() throws {
        let harness = try WelcomeHarness(step: .done, updatesConfigured: true)
        pickEverythingElse(harness.session.choices, harness.services.settings)
        harness.session.requestSkip()
        harness.session.skip()
        #expect(harness.outcomes.values == [.skipped])
        expectEveryWelcomeSettingIsDefault(harness.services.settings)
        #expect(harness.app.calls == ["setLaunchBehavior(launchOnly)"] && harness.app.loginItem == .enabled)
        #expect(harness.services.settings[OnboardingSettings.completedVersion] != nil)
        #expect(harness.boost.calls.isEmpty)
    }

    /// Step 2's "Use extra brightness" switches wait for Done like step 3's choices: Skip and the close button drop
    /// them (DESIGN.md §8: Skip applies every default), Done writes them with the OLED notice that was accepted.
    @Test(arguments: [WelcomeOutcome.skipped, .done])
    func stepTwoSwitchesWaitForDone(_ ending: WelcomeOutcome) throws {
        typealias Keys = DisplayFixture.Keys
        for closes in ending == .skipped ? [false, true] : [false] {
            let harness = try WelcomeHarness(.russianNames, step: .displays)
            let actions = harness.actions()
            actions.setExtraBrightness(true, for: try harness.row(Keys.mpg322ux))
            actions.setExtraBrightness(false, for: try harness.row(Keys.builtIn))
            switch (ending, closes) {
            case (.skipped, true): harness.session.windowWillClose()
            case (.skipped, false): harness.session.skip()
            default: harness.session.finish()
            }
            let stored = harness.services.settings[DisplaySettings.perDisplay]
            if ending == .done {
                #expect(stored[Keys.mpg322ux]?.boostEnabled == true && stored[Keys.mpg322ux]?.oledNoticeAcknowledged == true)
                #expect(stored[Keys.builtIn]?.boostEnabled == false && stored[Keys.builtIn]?.oledNoticeAcknowledged == false)
            } else {
                #expect(stored.isEmpty, "closed: \(closes)")
            }
            #expect(harness.boost.calls.isEmpty)
        }
    }

    /// The close button counts as Skip.
    @Test func theCloseButtonAppliesTheDefaultsToo() throws {
        let harness = try WelcomeHarness(step: .defaults, updatesConfigured: true)
        pickEverythingElse(harness.session.choices, harness.services.settings)
        harness.session.windowWillClose()
        #expect(harness.session.outcome == .skipped)
        expectEveryWelcomeSettingIsDefault(harness.services.settings)
        #expect(harness.app.calls == ["setLaunchBehavior(launchOnly)"])
    }

    /// Done applies every choice of step 3 and the update switch of step 5.
    @Test func doneAppliesTheChoices() throws {
        let harness = try WelcomeHarness(step: .done, updatesConfigured: true)
        let settings = harness.services.settings
        pickEverythingElse(harness.session.choices, settings)
        harness.session.finish()
        #expect(settings[AutomationSettings.batteryGuard] == .off)
        #expect(settings[AutomationSettings.batteryThreshold] == 50)
        #expect(!settings[AutomationSettings.pauseInLowPowerMode] && !settings[AutomationSettings.pauseForFullScreenVideo])
        #expect(settings[UpdateSettings.automatic])
        #expect(harness.app.calls == ["setLaunchBehavior(dontLaunch)"] && harness.app.loginItem == .disabled)
    }

    /// Done without touching anything keeps the defaults and registers the default login item.
    @Test func doneWithoutChangesKeepsTheDefaults() throws {
        let harness = try WelcomeHarness(step: .done, updatesConfigured: true)
        harness.session.finish()
        expectEveryWelcomeSettingIsDefault(harness.services.settings)
        #expect(harness.app.calls == ["setLaunchBehavior(launchOnly)"])
    }

    /// The update switch exists only with a repository (D2): without one, a stray choice never turns the check on.
    @Test func theUpdateChoiceNeedsARepository() throws {
        let harness = try WelcomeHarness(step: .done)
        #expect(!harness.session.plan.showsUpdateToggle)
        harness.session.choices.checksForUpdates = true
        harness.session.finish()
        #expect(!harness.services.settings[UpdateSettings.automatic])
    }

    /// Quit Overbright, on any step or in the Skip alert, applies nothing: Welcome shows again at the next launch.
    @Test func quitAppliesNothing() throws {
        let harness = try WelcomeHarness(step: .defaults, updatesConfigured: true)
        pickEverythingElse(harness.session.choices, harness.services.settings)
        harness.session.requestSkip()
        harness.session.quit()
        expectEveryWelcomeSettingIsDefault(harness.services.settings)
        #expect(harness.app.calls == ["quit"] && harness.services.settings[OnboardingSettings.completedVersion] == nil)
    }

    /// Welcome opened again from Settings ▸ About shows the stored settings; a Skip there (or the close button)
    /// registers the default login item, "Open Overbright, keep it off" (DESIGN.md §8: "Skip … applies every default,
    /// including the login item"), and keeps every other setting; Done writes only what was changed.
    @Test(arguments: [false, true])
    func aLaterRunKeepsWhatSettingsHold(_ closes: Bool) throws {
        for stored in [LaunchBehavior.launchAndEnable, .dontLaunch] {
            let harness = try WelcomeHarness(step: .defaults) { services in
                services.settings[AutomationSettings.batteryThreshold] = 30
                services.settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
                services.settings[GeneralSettings.launchBehavior] = stored
            }
            let choices = harness.session.choices, settings = harness.services.settings
            #expect(choices.batteryThreshold(in: settings) == 30 && choices.launchBehavior(in: settings) == stored)
            #expect(choices.pausesOnBattery(in: settings))                       // "Pause on battery" counts as on
            choices.pauseInLowPowerMode = false
            choices.launchBehavior = stored
            if closes { harness.session.windowWillClose() } else { harness.session.skip() }
            #expect(settings[AutomationSettings.batteryThreshold] == 30)
            #expect(settings[AutomationSettings.batteryGuard] == .onlyOnAdapter)
            #expect(settings[AutomationSettings.pauseInLowPowerMode])
            #expect(harness.app.calls == ["setLaunchBehavior(launchOnly)"], "stored \(stored), closed: \(closes)")
            #expect(harness.app.loginItem == .enabled)                            // the app stores it with the login item
        }

        let again = try WelcomeHarness(step: .done) { services in
            services.settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
        }
        again.session.choices.pauseForFullScreenVideo = false
        again.session.finish()
        #expect(again.services.settings[AutomationSettings.batteryGuard] == .onlyOnAdapter)
        #expect(!again.services.settings[AutomationSettings.pauseForFullScreenVideo])
    }

    /// The battery switch and its level pop-up (5–95 % in steps of 5, DESIGN.md §7.5).
    @Test func theBatterySwitchAndLevel() throws {
        let harness = try WelcomeHarness(step: .defaults)
        let choices = harness.session.choices, settings = harness.services.settings
        #expect(WelcomeChoices.batteryThresholds.first == 5 && WelcomeChoices.batteryThresholds.last == 95)
        #expect(WelcomeChoices.batteryThresholds.count == 19)
        choices.setPausesOnBattery(false, in: settings)
        #expect(choices.batteryGuard(in: settings) == .off && !choices.pausesOnBattery(in: settings))
        choices.setBatteryThreshold(37, in: settings)                            // a level turns the switch on
        #expect(choices.batteryThreshold(in: settings) == 35 && choices.batteryGuard(in: settings) == .belowThreshold)
        choices.batteryGuard = .onlyOnAdapter
        choices.setPausesOnBattery(true, in: settings)                           // already pausing: kept
        #expect(choices.batteryGuard(in: settings) == .onlyOnAdapter)
        #expect(settings.isDefault(AutomationSettings.batteryGuard))             // nothing stored before Done
    }

    /// A scripted visual QA run (`--qa-welcome`) applies nothing, picks or not.
    @Test func visualQAAppliesNothing() throws {
        let harness = try WelcomeHarness(step: .done, updatesConfigured: true, records: false)
        pickEverythingElse(harness.session.choices, harness.services.settings)
        harness.session.finish()
        expectEveryWelcomeSettingIsDefault(harness.services.settings)
        #expect(harness.app.calls.isEmpty)
    }
}
