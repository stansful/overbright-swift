// OverbrightCore/Ports/AppControl.swift — app-level actions (implemented by the shell's ShellAppControl).
// ARCHITECTURE.md §3.6, §7.6, D13.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// Windows, login item, menu bar icon and app-wide actions.
@MainActor public protocol AppControl: AnyObject, Observable {
    /// The login item's state.
    var loginItem: LoginItemState { get }
    /// Whether the status item can be seen.
    var iconVisibility: MenuBarIconVisibility { get }
    /// Opens the panel under the status item.
    func showPanel()
    /// "pane" or "pane#row" (Cranny deep links); nil = the last pane.
    func openSettings(_ pane: String?)
    /// Opens the Welcome window.
    func showWelcome()
    /// The local Help window, optionally scrolled to an anchor ("no-extra-range", "control-center", …).
    func showHelp(anchor: String?)
    /// Opens the calibration window for a display.
    func showCalibration(for display: DisplayKey)
    /// Registers or unregisters the login item.
    func setLaunchBehavior(_ behavior: LaunchBehavior)
    /// Shows or hides the status item.
    func setMenuBarIconVisible(_ visible: Bool)
    /// Copies the diagnostics report to the clipboard.
    func copyDiagnostics()
    /// Offers a Save panel for a self-test log.
    func saveSelfTestLog(_ report: SelfTestReport)
    /// With Undo until the Settings window closes.
    func resetAllSettings()
    /// Undoes the last Reset All.
    func undoResetAllSettings()
    /// Quits (ramped stop first, D7).
    func quit()
}
