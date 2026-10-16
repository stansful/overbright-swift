// OverbrightAppShell/Services/ShellAppControl.swift — the shell's `AppControl`: what the panel, Settings, Welcome,
// Help and the menu ask the app to do. ARCHITECTURE.md §3.6, §3.11, §10.0 (shared shell file, contract owner).
// Constructed before the windows exist; `connect(…)` hands it the controllers that implement each request. Until then
// (and in a command-line mode) every request is a no-op.
import AppKit
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Implements `AppControl` over the shell's controllers.
@Observable final class ShellAppControl: AppControl {
    /// The login item's state. WP0a: unavailable until WP0b's `LoginItemController` reads `SMAppService`.
    private(set) var loginItem: LoginItemState = .unavailable
    /// Whether the status item can be seen (General ▸ Show menu bar icon, and the visibility check).
    private(set) var iconVisibility: MenuBarIconVisibility = .visible

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var controllers: Controllers?
    @ObservationIgnored private var resetUndo: SettingsStore.Snapshot?

    /// The controllers behind the requests.
    struct Controllers {
        let statusItem: StatusItemController
        let panel: PanelController
        let settings: SettingsWindowController
        let welcome: WelcomeWindowController
        let help: HelpWindowController
        let calibration: CalibrationWindowController
        let selfTest: SelfTestSheetPresenter
        /// The diagnostics report as JSON (Copy Diagnostics: no bundle facts, with the journal).
        let diagnostics: @MainActor () -> Data?
    }

    /// A control writing `settings`; nothing works until `connect(_:)`.
    init(settings: SettingsStore) {
        self.settings = settings
        iconVisibility = settings[GeneralSettings.showsMenuBarIcon] ? .visible : .hiddenByUser
    }

    /// Hands over the controllers (once, by the app delegate after the windows exist).
    func connect(_ controllers: Controllers) { self.controllers = controllers }

    /// Records the status item's visibility (the icon visibility monitor's result, WP10).
    func updateIconVisibility(_ visibility: MenuBarIconVisibility) { iconVisibility = visibility }

    // MARK: AppControl

    /// The panel under the icon (at the top of the main screen while the icon is hidden).
    func showPanel() {
        guard let controllers else { return }
        controllers.panel.show(from: controllers.statusItem.button)
    }

    /// Settings at `pane` ("pane" or "pane#row").
    func openSettings(_ pane: String?) { controllers?.settings.show(pane: pane) }

    /// Welcome at its first unfinished step.
    func showWelcome() { controllers?.welcome.show(step: nil) }

    /// Help, scrolled to `anchor`.
    func showHelp(anchor: String?) { controllers?.help.show(anchor: anchor) }

    /// The calibration window for `display`.
    func showCalibration(for display: DisplayKey) { controllers?.calibration.show(display: display) }

    /// Stores the launch behaviour (the login item follows it once WP0b's controller exists).
    func setLaunchBehavior(_ behavior: LaunchBehavior) { settings[GeneralSettings.launchBehavior] = behavior }

    /// Shows or hides the status item.
    func setMenuBarIconVisible(_ visible: Bool) {
        settings[GeneralSettings.showsMenuBarIcon] = visible
        controllers?.statusItem.setVisible(visible)
        iconVisibility = visible ? .visible : .hiddenByUser
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

    /// Reset All, with Undo until the Settings window closes.
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
}
