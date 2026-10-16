// OverbrightSettingsUITests/KeyboardAndResetTests.swift — the shortcut recorder's rules and the system-shortcut check
// (DESIGN.md §7.6), Reset ‹Pane›… and Reset All with Undo (§7.2, §7.8, §12.4, §12.9), and the value formats (§12.5).
// Ported from Cranny's KeyboardAndResetTests (the owner's MIT code).
import AppKit
import Foundation
import Observation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightSettingsUI

private let hyper: KeyCombo.Modifiers = [.control, .option, .command]

/// The format of `com.apple.symbolichotkeys` on macOS 27: `parameters` = [ascii, keyCode, NSEvent modifier flags].
private let domain: [String: Any] = [
    "64": ["enabled": false, "value": ["type": "standard", "parameters": [32, 49, 1_048_576]]],          // Spotlight off
    "118": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 18, 262_144]]],        // ⌃1
    "79": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 123, 8_650_752]]],      // fn⌃←
    "163": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 65535, 0]]],           // no key
    "garbage": ["enabled": true],
    "999": "not a dictionary",
]

/// Resets the store like the shell's `ShellAppControl` (snapshot, reset, restore on undo).
@MainActor @Observable private final class ResettingAppControl: AppControl {
    let settings: SettingsStore
    var loginItem: LoginItemState = .disabled
    var iconVisibility: MenuBarIconVisibility = .visible
    private(set) var resets = 0
    private(set) var undos = 0
    @ObservationIgnored private var snapshot: SettingsStore.Snapshot?
    init(settings: SettingsStore) { self.settings = settings }
    func showPanel() {}
    func openSettings(_ pane: String?) {}
    func showWelcome() {}
    func showHelp(anchor: String?) {}
    func showCalibration(for display: DisplayKey) {}
    func setLaunchBehavior(_ behavior: LaunchBehavior) {}
    func setMenuBarIconVisible(_ visible: Bool) {}
    func copyDiagnostics() {}
    func saveSelfTestLog(_ report: SelfTestReport) {}
    func resetAllSettings() { resets += 1; snapshot = settings.snapshot(); settings.resetAll() }
    func undoResetAllSettings() { undos += 1; if let snapshot { settings.restore(snapshot) } }
    func quit() {}
}

private let marker = BoostMarker(since: Date(timeIntervalSinceReferenceDate: 800_000_000),
                                 displays: [DisplayKey(rawValue: "37D8832A-2D66-02CA-B9F7-8F30A301B230")], maxFactor: 1.3)

@MainActor @Suite struct KeyboardAndResetTests {
    // MARK: Recorder rules

    @Test func theRecorderNeedsACommandModifierExceptForFunctionKeys() {
        let n: UInt16 = 45
        #expect(KeyComboFormatter.outcome(keyCode: n, modifiers: []) == .needsModifier)
        #expect(KeyComboFormatter.outcome(keyCode: n, modifiers: [.shift]) == .needsModifier)
        #expect(KeyComboFormatter.outcome(keyCode: 53, modifiers: []) == .cancel)                // Esc
        #expect(KeyComboFormatter.outcome(keyCode: 51, modifiers: []) == .clear)                 // Delete
        #expect(KeyComboFormatter.outcome(keyCode: 117, modifiers: []) == .clear)                // Forward Delete
        #expect(KeyComboFormatter.outcome(keyCode: n, modifiers: [.control, .option])
                == .combo(KeyCombo(keyCode: n, modifiers: [.control, .option])))
        #expect(KeyComboFormatter.outcome(keyCode: 122, modifiers: []) == .combo(KeyCombo(keyCode: 122, modifiers: [])))
        #expect(KeyComboFormatter.outcome(keyCode: 53, modifiers: [.command])
                == .combo(KeyCombo(keyCode: 53, modifiers: [.command])))                         // ⌘⎋ is a shortcut
        #expect(KeyComboFormatter.modifiers([.command, .capsLock, .function, .shift]) == [.command, .shift])
    }

    /// The recorder's caps come from Core's layout function: the same text as the menu and `displayString`.
    @Test func theRecorderDrawsKeyCapsThroughTheLayout() throws {
        let german = try #require(KeyCombo.KeyboardLayout.named("com.apple.keylayout.German"))
        #expect(KeyCombo(keyCode: 27, modifiers: hyper).keyCaps(in: german, spaceName: KeyComboFormatter.spaceName)
                == "⌃⌥⌘ß")
        #expect(!KeyComboFormatter.keyCaps(KeyCombo(keyCode: 11, modifiers: hyper)).isEmpty)
    }

    /// One recorder listens at a time: starting another stops the first.
    @Test func onlyOneRecorderListens() {
        let recording = ShortcutRecording()
        var stopped: [String] = []
        let first = UUID(), second = UUID()
        recording.begin(first) { stopped.append("first") }
        recording.begin(second) { stopped.append("second") }
        #expect(stopped == ["first"] && recording.activeID == second)
        recording.end(first)                                                       // stale: no effect
        #expect(recording.activeID == second)
        recording.end(second)
        #expect(recording.activeID == nil)
    }

    // MARK: System shortcuts (best effort)

    @Test func systemShortcutsParseTheDomainAndFillDefaults() {
        let shortcuts = SystemShortcuts.enabled(from: domain)
        #expect(!shortcuts.contains { $0.id == 64 })                              // the user turned Spotlight off
        #expect(shortcuts.contains(SystemShortcut(id: 118, keyCode: 18, modifiers: [.control])))
        #expect(shortcuts.contains(SystemShortcut(id: 79, keyCode: 123, modifiers: [.control])))   // Fn ignored
        #expect(!shortcuts.contains { $0.id == 163 })
        #expect(shortcuts.contains { $0.id == 61 })                               // a default the domain does not list
        #expect(SystemShortcuts.enabled(from: nil).count == SystemShortcuts.defaults.count)
    }

    /// D17: the defaults avoid every enabled macOS shortcut; the accessibility neighbours are known by name.
    @Test func theDesignDefaultsCollideWithNoKnownSystemShortcut() throws {
        let shortcuts = SystemShortcuts.enabled(from: [:])
        for shortcut in ShortcutCatalog.all {
            guard let combo = shortcut.defaultCombo else { continue }
            #expect(SystemShortcuts.conflict(for: combo, in: shortcuts) == nil, "\(shortcut.id)")
        }
        let invert = KeyCombo(keyCode: 28, modifiers: hyper)                       // ⌃⌥⌘8
        let clash = try #require(SystemShortcuts.conflict(for: invert, in: shortcuts))
        #expect(clash.id == 21 && SystemShortcuts.name(of: 21) != nil)
        let spotlight = KeyCombo(keyCode: 49, modifiers: [.command])
        #expect(SystemShortcuts.conflict(for: spotlight, in: shortcuts)?.id == 64)
        #expect(SystemShortcuts.conflict(for: KeyCombo(keyCode: 49, modifiers: [.command, .shift]), in: shortcuts) == nil)
    }

    // MARK: Reset ‹Pane›…

    /// A pane reset clears its namespaces but keeps the records that live there (the pause deadline, the last check).
    @Test func paneResetKeepsRecords() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        settings[AutomationSettings.batteryThreshold] = 40
        settings[AutomationSettings.pausedUntil] = deadline
        settings[UpdateSettings.automatic] = true
        settings[UpdateSettings.lastCheck] = deadline
        settings[GeneralSettings.showsHUD] = false
        PaneReset.reset(SettingsPane.pane(.automations).namespaces, settings: settings)
        #expect(settings[AutomationSettings.batteryThreshold] == 20)
        #expect(settings[AutomationSettings.pausedUntil] == deadline)
        #expect(!settings[GeneralSettings.showsHUD])                               // other panes untouched
        PaneReset.reset(SettingsPane.pane(.general).namespaces, settings: settings)
        #expect(settings[GeneralSettings.showsHUD] && !settings[UpdateSettings.automatic])
        #expect(settings[UpdateSettings.lastCheck] == deadline)
    }

    @Test func theDisplaysResetMentionsCalibration() {
        #expect(PaneFooter.message(for: .pane(.displays)) != PaneFooter.message(for: .pane(.general)))
    }

    // MARK: Reset All with Undo

    /// Through the app (the shell keeps the snapshot): reset, then undo until the window closes; the boost marker is a
    /// record and survives both.
    @Test func resetAllCanBeUndoneUntilTheWindowCloses() {
        let services = OverbrightServices.preview()
        let app = ResettingAppControl(settings: services.settings)
        services.app = app
        services.settings[DisplaySettings.linkLevels] = true
        services.settings[EngineRecords.boostMarker] = marker
        let controller = ResetAllController(services: services, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        controller.resetAll()
        #expect(app.resets == 1 && controller.canUndo && controller.showsBanner)
        #expect(!services.settings[DisplaySettings.linkLevels])
        #expect(services.settings[EngineRecords.boostMarker] == marker)          // a record, not a setting
        controller.dismissBanner()                                               // the banner goes, Undo stays
        #expect(!controller.showsBanner && controller.canUndo)
        controller.undo()
        #expect(app.undos == 1 && !controller.canUndo)
        #expect(services.settings[DisplaySettings.linkLevels])
        #expect(services.settings[EngineRecords.boostMarker] == marker)
        controller.undo()                                                        // nothing left to undo
        #expect(app.undos == 1)
    }

    @Test func closingTheWindowEndsTheOffer() {
        let services = OverbrightServices.preview()
        services.app = nil                                                       // previews: the store directly
        services.settings[GeneralSettings.haptics] = false
        let session = SettingsSession(services: services)
        session.resetAll.resetAll()
        #expect(services.settings[GeneralSettings.haptics] && session.canUndoReset)
        session.windowDidClose()
        #expect(!session.canUndoReset)
        session.resetAll.undo()
        #expect(services.settings[GeneralSettings.haptics])                      // the reset stays
    }

    @Test func withoutAnAppTheControllerKeepsItsOwnSnapshot() {
        let services = OverbrightServices.preview()
        services.app = nil
        services.settings[ShortcutSettings.stepSize] = .fine
        let controller = ResetAllController(services: services)
        controller.resetAll()
        #expect(services.settings[ShortcutSettings.stepSize] == .regular)
        controller.undo()
        #expect(services.settings[ShortcutSettings.stepSize] == .fine)
    }

    @Test func theBannerEndsAfterItsTimeButUndoStays() async {
        let services = OverbrightServices.preview()
        services.app = ResettingAppControl(settings: services.settings)
        let controller = ResetAllController(services: services, bannerTime: .milliseconds(1), sleep: { _ in })
        controller.resetAll()
        #expect(await eventually { !controller.showsBanner })
        #expect(controller.canUndo)
        #expect(controller.takeAnnouncement() && !controller.takeAnnouncement())  // announced once per offer
    }

    /// ⌘Z is Edit ▸ Undo through the responder chain: Reset All sits on the window's undo stack, so the window's undo
    /// (no hidden key equivalent) restores the settings once.
    @Test func resetAllIsOnTheWindowsUndoStack() {
        let services = OverbrightServices.preview()
        let app = ResettingAppControl(settings: services.settings)
        services.app = app
        services.settings[DisplaySettings.linkLevels] = true
        let manager = UndoManager()
        manager.groupsByEvent = false                                            // no run loop in a test
        let controller = ResetAllController(services: services, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        controller.undoManager = manager
        #expect(!manager.canUndo)
        controller.resetAll()
        #expect(manager.canUndo)
        manager.undo()
        #expect(app.undos == 1 && !controller.canUndo && services.settings[DisplaySettings.linkLevels])
        #expect(!manager.canUndo)
    }

    /// A focused text field (the sidebar search) registers its typing on the same manager after the reset: ⌘Z undoes
    /// the typing first and leaves Reset All for the next ⌘Z.
    @Test func aTextFieldsOwnUndoComesFirst() {
        let services = OverbrightServices.preview()
        let app = ResettingAppControl(settings: services.settings)
        services.app = app
        let manager = UndoManager()
        manager.groupsByEvent = false
        let controller = ResetAllController(services: services, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        controller.undoManager = manager
        controller.resetAll()
        final class Field { var text = "disp" }
        let field = Field()
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: field) { $0.text = "" }                 // what typing registers
        manager.endUndoGrouping()
        manager.undo()
        #expect(field.text.isEmpty && app.undos == 0 && controller.canUndo)
        manager.undo()
        #expect(app.undos == 1 && !controller.canUndo)
    }

    /// Undo from the banner or the Undo Reset button, or closing the window, takes the offer off the stack: a later ⌘Z
    /// does nothing to the settings.
    @Test func undoByButtonOrClosingLeavesNothingOnTheStack() {
        let services = OverbrightServices.preview()
        let app = ResettingAppControl(settings: services.settings)
        services.app = app
        let manager = UndoManager()
        manager.groupsByEvent = false
        let session = SettingsSession(services: services)
        session.resetAll.undoManager = manager
        session.resetAll.resetAll()
        session.resetAll.undo()                                                  // the button
        #expect(app.undos == 1 && !manager.canUndo)
        session.resetAll.resetAll()
        #expect(manager.canUndo)
        session.windowDidClose()
        #expect(!manager.canUndo && app.undos == 1)
    }

    // MARK: Formats (DESIGN.md §12.5)

    @Test func valuesCarryTheirUnitsInTheLocale() {
        let english = Locale(identifier: "en_US"), russian = Locale(identifier: "ru_RU")
        #expect(SettingsFormat.percent(0.8, locale: english) == "80%")
        #expect(SettingsFormat.kelvin(5100, locale: english) == "5,100 K")
        let russianKelvin = SettingsFormat.kelvin(5100, locale: russian)
        #expect(russianKelvin != SettingsFormat.kelvin(5100, locale: english) && russianKelvin.contains("100"))
        #expect(SettingsFormat.minutes(90, locale: english) == "1 hr, 30 min")
        #expect(SettingsFormat.points(48, locale: english) == "48 pt")
    }
}
