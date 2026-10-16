// OverbrightSettingsUITests/Support/StoringAppControl.swift — an `AppControl` that stores what the shell's
// `ShellAppControl` stores (the launch behaviour, the icon's visibility) and keeps a Reset All snapshot, recording
// every call. The preview control records calls only, so a reset through it would change no setting.
import Foundation
import Observation
import OverbrightCore

/// An app control writing the settings store as the shell does.
@MainActor @Observable final class StoringAppControl: AppControl {
    let settings: SettingsStore
    var loginItem: LoginItemState = .enabled
    var iconVisibility: MenuBarIconVisibility = .visible
    private(set) var calls: [String] = []
    @ObservationIgnored private var snapshot: SettingsStore.Snapshot?

    init(settings: SettingsStore) { self.settings = settings }

    func showPanel() { calls.append("showPanel") }
    func openSettings(_ pane: String?) { calls.append("openSettings(\(pane ?? "-"))") }
    func showWelcome() { calls.append("showWelcome") }
    func showHelp(anchor: String?) { calls.append("showHelp") }
    func showCalibration(for display: DisplayKey) { calls.append("showCalibration(\(display.rawValue))") }
    func setLaunchBehavior(_ behavior: LaunchBehavior) {
        calls.append("setLaunchBehavior(\(behavior.rawValue))")
        settings[GeneralSettings.launchBehavior] = behavior
    }
    func setMenuBarIconVisible(_ visible: Bool) {
        calls.append("setMenuBarIconVisible(\(visible))")
        settings[GeneralSettings.showsMenuBarIcon] = visible
        iconVisibility = visible ? .visible : .hiddenByUser
    }
    func copyDiagnostics() { calls.append("copyDiagnostics") }
    func saveSelfTestLog(_ report: SelfTestReport) { calls.append("saveSelfTestLog") }
    func resetAllSettings() { calls.append("resetAllSettings"); snapshot = settings.snapshot(); settings.resetAll() }
    func undoResetAllSettings() {
        calls.append("undoResetAllSettings")
        if let snapshot { settings.restore(snapshot) }
        snapshot = nil
    }
    func quit() { calls.append("quit") }
}
