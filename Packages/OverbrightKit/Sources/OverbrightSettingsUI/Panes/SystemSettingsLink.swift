// OverbrightSettingsUI/Panes/SystemSettingsLink.swift — the System Settings panes and apps the Settings copy names, for
// its "Open System Settings" and "Open Shortcuts" buttons (DESIGN.md §16: a button that opens System Settings is always
// "Open System Settings", and the sentence beside it names the pane). The same addresses as PanelUI's `SettingsLinks`
// (an L2 module cannot import another).
import AppKit
import Foundation

/// Where "Open System Settings" and "Open Shortcuts" go.
enum SystemSettingsLink {
    /// System Settings ▸ Displays (verdict fixes).
    static let displays = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")
    /// System Settings ▸ General ▸ Login Items (a login item that waits for approval).
    static let loginItems = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    /// System Settings ▸ Focus (Automations ▸ Focus).
    static let focus = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")
    /// System Settings ▸ Menu Bar (the icon isn't visible).
    static let menuBar = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")
    /// The Shortcuts app.
    static let shortcutsApp = URL(string: "shortcuts://")

    /// Opens `url` (a System Settings pane or an app); nothing when it is nil.
    @MainActor static func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// "Open System Settings": the title of every button that opens System Settings (DESIGN.md §16).
    static var openSystemSettings: String {
        String(localized: "Open System Settings", bundle: .module,
               comment: "Settings: button that opens System Settings; the sentence beside it names the pane (title case)")
    }
}
