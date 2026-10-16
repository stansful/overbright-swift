// OverbrightCore/Fakes/PreviewAppControl.swift — an in-memory AppControl. ARCHITECTURE.md §3.9.
import Observation

/// An `AppControl` that keeps its state in memory and records every call ("openSettings(displays#cap)").
@MainActor @Observable public final class PreviewAppControl: AppControl {
    /// The login item's state (settable).
    public var loginItem: LoginItemState
    /// The icon's visibility (settable).
    public var iconVisibility: MenuBarIconVisibility
    /// Every call, in order.
    public private(set) var calls: [String] = []
    /// No login item, icon visible by default.
    public init(loginItem: LoginItemState = .disabled, iconVisibility: MenuBarIconVisibility = .visible) {
        self.loginItem = loginItem; self.iconVisibility = iconVisibility
    }
    /// Records the call.
    public func showPanel() { calls.append("showPanel") }
    /// Records the pane.
    public func openSettings(_ pane: String?) { calls.append("openSettings(\(pane ?? "-"))") }
    /// Records the call.
    public func showWelcome() { calls.append("showWelcome") }
    /// Records the anchor.
    public func showHelp(anchor: String?) { calls.append("showHelp(\(anchor ?? "-"))") }
    /// Records the display.
    public func showCalibration(for display: DisplayKey) { calls.append("showCalibration(\(display.rawValue))") }
    /// Sets `loginItem` (enabled unless `dontLaunch`).
    public func setLaunchBehavior(_ behavior: LaunchBehavior) {
        calls.append("setLaunchBehavior(\(behavior.rawValue))")
        loginItem = behavior == .dontLaunch ? .disabled : .enabled
    }
    /// Sets `iconVisibility`.
    public func setMenuBarIconVisible(_ visible: Bool) {
        calls.append("setMenuBarIconVisible(\(visible))")
        iconVisibility = visible ? .visible : .hiddenByUser
    }
    /// Records the call.
    public func copyDiagnostics() { calls.append("copyDiagnostics") }
    /// Records the call.
    public func saveSelfTestLog(_ report: SelfTestReport) { calls.append("saveSelfTestLog") }
    /// Records the call.
    public func resetAllSettings() { calls.append("resetAllSettings") }
    /// Records the call.
    public func undoResetAllSettings() { calls.append("undoResetAllSettings") }
    /// Records the call.
    public func quit() { calls.append("quit") }
}
