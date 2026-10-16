// OverbrightAppShell/Services/ShellAppControl.swift — the shell's `AppControl`: what the panel, Settings, Welcome,
// Help and the menu ask the app to do. ARCHITECTURE.md §3.6, §3.11, §7.6, §10.0 (shared shell file), §10.15.
// Constructed before the windows exist; `connect(…)` hands it the controllers that implement each request. Until then
// (and in a command-line mode) every window request is a no-op.
//
// The login item follows General ▸ When you log in (`LoginItemController`, `SMAppService.mainApp`; in memory under
// `--qa-simulate`) and the status item follows General ▸ Show menu bar icon, whoever writes the setting (the row,
// Welcome, Reset All and its Undo), so they never disagree with Settings.
import AppKit
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Implements `AppControl` over the shell's controllers.
@Observable final class ShellAppControl: AppControl {
    /// Whether the status item can be seen (General ▸ Show menu bar icon, and the visibility check).
    private(set) var iconVisibility: MenuBarIconVisibility = .visible

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored let loginItems: LoginItemController
    @ObservationIgnored private var controllers: Controllers?
    @ObservationIgnored private var resetUndo: SettingsStore.Snapshot?
    @ObservationIgnored private var observations: [ObservationToken] = []
    @ObservationIgnored private var isIconInstalled = false

    /// The controllers behind the requests.
    struct Controllers {
        let icon: StatusIconPresence
        let panel: PanelController
        let settings: SettingsWindowController
        let welcome: WelcomeWindowController
        let help: HelpWindowController
        let calibration: CalibrationWindowController
        let selfTest: SelfTestSheetPresenter
        /// The diagnostics report as JSON (Copy Diagnostics: no bundle facts, with the journal).
        let diagnostics: @MainActor () -> Data?
    }

    /// A control writing `settings`, with `loginItems` behind the login item; nothing works until `connect(_:)`.
    init(settings: SettingsStore, loginItems: LoginItemController) {
        self.settings = settings
        self.loginItems = loginItems
        iconVisibility = settings[GeneralSettings.showsMenuBarIcon] ? .visible : .hiddenByUser
    }

    /// The login item's state (read from `SMAppService` on first use, again whenever the app becomes active).
    var loginItem: LoginItemState { loginItems.state }

    /// Hands over the controllers (once, by the app delegate after the windows exist) and follows the two settings that
    /// drive the login item and the icon. Puts nothing in the menu bar: `installIcon()` does.
    func connect(_ controllers: Controllers) {
        self.controllers = controllers
        controllers.icon.onVisibilityChange = { [weak self] visibility in self?.updateIconVisibility(visibility) }
        loginItems.start()
        let settings = settings
        observations = [
            observe({ settings[GeneralSettings.launchBehavior] }) { [weak self] behavior in
                self?.loginItems.apply(behavior)
            },
            observe({ settings[GeneralSettings.showsMenuBarIcon] }) { [weak self] visible in self?.showIcon(visible) },
        ]
    }

    /// Adds the status item to the menu bar (shown or hidden as General ▸ Show menu bar icon says) and starts its
    /// visibility check (the app delegate, once, never in a command-line mode).
    func installIcon() {
        guard let controllers, !isIconInstalled else { return }
        isIconInstalled = true
        controllers.icon.install(visible: settings[GeneralSettings.showsMenuBarIcon])
    }

    /// Records the status item's visibility (the visibility monitor's result).
    func updateIconVisibility(_ visibility: MenuBarIconVisibility) {
        if iconVisibility != visibility { iconVisibility = visibility }
    }

    // MARK: AppControl

    /// The panel under the icon (at the top of the main screen while the icon is hidden).
    func showPanel() {
        guard let controllers else { return }
        controllers.panel.show(from: controllers.icon.statusItem.button)
    }

    /// Settings at `pane` ("pane" or "pane#row").
    func openSettings(_ pane: String?) { controllers?.settings.show(pane: pane) }

    /// Welcome at its first unfinished step.
    func showWelcome() { controllers?.welcome.show(step: nil) }

    /// Help, scrolled to `anchor`.
    func showHelp(anchor: String?) { controllers?.help.show(anchor: anchor) }

    /// The calibration window for `display`.
    func showCalibration(for display: DisplayKey) { controllers?.calibration.show(display: display) }

    /// Stores the launch behaviour and registers or removes the login item at once.
    func setLaunchBehavior(_ behavior: LaunchBehavior) {
        settings[GeneralSettings.launchBehavior] = behavior
        loginItems.apply(behavior)
    }

    /// Shows or hides the status item.
    func setMenuBarIconVisible(_ visible: Bool) {
        settings[GeneralSettings.showsMenuBarIcon] = visible
        showIcon(visible)
    }

    /// Advanced ▸ Copy Diagnostics: the report on the clipboard, never uploaded.
    func copyDiagnostics() {
        guard let data = controllers?.diagnostics() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string)
    }

    /// Saves a self-test log through a Save panel (WP11's `SelfTestSheetPresenter.saveLog`).
    func saveSelfTestLog(_ report: SelfTestReport) {
        guard let controllers else {
            log.info("save self-test log requested before the windows exist (\(report.displays.count, privacy: .public) displays)")
            return
        }
        controllers.selfTest.saveLog(report)
    }

    /// Reset All, with Undo until the Settings window closes (the login item and the icon follow their settings).
    func resetAllSettings() {
        resetUndo = settings.snapshot()
        settings.resetAll()
    }

    /// Undoes the last Reset All.
    func undoResetAllSettings() {
        guard let snapshot = resetUndo else { return }
        settings.restore(snapshot)
        resetUndo = nil
    }

    /// Quits Overbright (the ramped stop runs in `applicationShouldTerminate`).
    func quit() { NSApp.terminate(nil) }

    // MARK: Private

    private func showIcon(_ visible: Bool) {
        guard let controllers, isIconInstalled else {
            iconVisibility = visible ? .visible : .hiddenByUser
            return
        }
        updateIconVisibility(controllers.icon.setVisible(visible))
    }
}
