// OverbrightSettingsUITests/PausedAppsEditorTests.swift — Automations ▸ Pause for these apps (DESIGN.md §7.5;
// ARCHITECTURE.md §3.4, §6.5): adding (once, case-insensitively, with the suggested mode), removing, changing an app's
// mode, the suggestions (not listed yet, installed only), Reset to Default restoring the twelve apps and the switch,
// the VoiceOver names of the app rows, and the add control as DESIGN.md's + menu (WP14).
// Synthetic bundle IDs only, besides the default list's (ARCHITECTURE.md D3).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct PausedAppsEditorTests {
    private let defaults = PausedAppDefaults.rules

    @Test func addingAppendsOnceWithTheSuggestedMode() {
        var rules = PausedAppsList.adding(["com.example.player", "COM.EXAMPLE.PLAYER", ""], to: [])
        #expect(rules == [PausedAppRule(bundleID: "com.example.player", mode: .whileFrontmost)])
        rules = PausedAppsList.adding(["com.colliderli.iina"], to: rules)          // a suggested player plays
        #expect(rules.last == PausedAppRule(bundleID: "com.colliderli.iina", mode: .whilePlaying))
        #expect(PausedAppsList.adding(["com.example.player"], to: rules) == rules)
    }

    @Test func removingAndChangingTheModeTouchOnlyThatApp() {
        let rules = PausedAppsList.removing("COM.APPLE.TV", from: defaults)
        #expect(rules.count == defaults.count - 1 && !PausedAppsList.contains("com.apple.TV", in: rules))
        let changed = PausedAppsList.setting(.whileFrontmost, for: "com.colliderli.iina", in: defaults)
        #expect(changed.first { $0.bundleID == "com.colliderli.iina" }?.mode == .whileFrontmost)
        #expect(zip(changed, defaults).filter { $0.0 != $0.1 }.count == 1)
    }

    /// Suggestions: the default list's apps the user removed, then the extra video apps; installed ones only.
    @Test func suggestionsAreInstalledAppsNotListedYet() {
        let installed: Set = ["com.apple.QuickTimePlayerX", "com.moonlight-stream.Moonlight", "com.amazon.aiv.AIVApp"]
        let listed = PausedAppsList.removing("com.apple.QuickTimePlayerX", from: defaults)
        let suggestions = PausedAppsList.suggestions(for: listed) { installed.contains($0) }
        #expect(suggestions.map(\.bundleID) == ["com.apple.QuickTimePlayerX", "com.amazon.aiv.AIVApp",
                                                "com.moonlight-stream.Moonlight"])
        #expect(PausedAppsList.suggestions(for: defaults + PausedAppsList.extraSuggestions) { _ in true }.isEmpty)
        #expect(PausedAppsList.suggestedMode(for: "com.amazon.aiv.AIVApp") == .whilePlaying)
        #expect(PausedAppsList.suggestedMode(for: "com.nvidia.gfnpc.mall") == .whileFrontmost)
    }

    /// The extra suggestions are not on the default list (DESIGN.md §7.5 names them separately).
    @Test func extraSuggestionsAreNew() {
        #expect(PausedAppsList.extraSuggestions.count == 4)
        #expect(PausedAppsList.extraSuggestions.allSatisfy { !PausedAppsList.contains($0.bundleID, in: defaults) })
        #expect(defaults.count == 12)
    }

    /// Reset to Default of the list's row restores both the switch and the twelve default apps.
    @Test func resetRestoresTheSwitchAndTheDefaultApps() {
        let services = OverbrightServices.preview()
        let settings = services.settings
        let value = AutomationsPane.pausedAppsValue(services)
        #expect(value.isDefault())
        settings[AutomationSettings.pausedApps] = PausedAppsList.adding(["com.example.player"],
                                                                         to: PausedAppsList.removing("com.apple.TV", from: defaults))
        #expect(!value.isDefault())
        settings[AutomationSettings.pauseForListedApps] = false
        value.reset()
        #expect(settings[AutomationSettings.pausedApps] == defaults && settings[AutomationSettings.pauseForListedApps])
        #expect(value.isDefault())
    }

    /// VoiceOver names every row's mode pop-up (never "While in front, pop-up button" alone), and the names inside
    /// "Remove ‹App›" and "Always continue next to ‹App›" are bidi-isolated (ARCHITECTURE.md §8.8).
    @Test func everyAppRowIsNamedForVoiceOverWithItsNameIsolated() {
        let pending = AppIdentity(bundleID: "com.example.player")
        let gone = AppIdentity(bundleID: "com.example.gone", presence: .notInstalled)
        let named = AppIdentity(bundleID: "com.example.player", presence: .installed, name: "נגן")
        #expect(PausedAppsEditor.spokenName(pending) == "com.example.player")
        #expect(PausedAppsEditor.spokenName(gone) == PausedAppsEditor.notInstalled && !PausedAppsEditor.notInstalled.isEmpty)
        #expect(PausedAppsEditor.spokenName(named) == "נגן")
        #expect(PausedAppsEditor.removeLabel(named).contains(BidiIsolation.isolate("נגן")))
        #expect(PausedAppsEditor.removeLabel(gone) == PausedAppsEditor.removeLabel(pending))     // "Remove app"
        let colors = ConflictingApp(entryID: "S2-example", severity: .gammaWriter, bundleID: nil, processID: 7,
                                    displayName: "Colors")
        let tint = ConflictingApp(entryID: "S3-example", severity: .conditional, bundleID: nil, processID: 8,
                                  displayName: "מסנן")
        #expect(OtherAppsSection.alwaysContinueLabel(colors).contains(BidiIsolation.isolate("Colors")))
        #expect(OtherAppsSection.alwaysContinueLabel(tint).contains(BidiIsolation.isolate("מסנן")))
        #expect(OtherAppsSection.alwaysContinueLabel(colors) != OtherAppsSection.alwaysContinueLabel(tint))
    }

    /// The add control is DESIGN.md §7.5's **+** menu: a glyph, as narrow in every language as in English (the words
    /// "Add App" took about twice the room, more in a long translation), with "Add App" as its VoiceOver label and help
    /// tag (C-SETTINGS-11).
    @Test func theAddControlIsAPlusMenuNamedForVoiceOver() {
        let menu = AddPausedAppMenu(rules: PausedAppDefaults.rules) { _ in }
        let width = NSHostingView(rootView: menu).fittingSize.width
        let words = NSHostingView(rootView: Menu { Button {} label: { Text(verbatim: "Choose…") } } label: {
            Text(verbatim: AddPausedAppMenu.title)
        }.fixedSize()).fittingSize.width
        #expect(AddPausedAppMenu.symbol == .plus)
        #expect(width + 20 < words, "the + menu is \(width) pt, the words \(words) pt")
        #expect(AddPausedAppMenu.title == "Add App")
    }

    /// Turning the list's switch off keeps every rule (DESIGN.md §5.9).
    @Test func theSwitchKeepsTheRules() {
        let settings = OverbrightServices.preview().settings
        settings[AutomationSettings.pausedApps] = PausedAppsList.adding(["com.example.player"], to: defaults)
        settings[AutomationSettings.pauseForListedApps] = false
        #expect(settings[AutomationSettings.pausedApps].count == defaults.count + 1)
    }
}
