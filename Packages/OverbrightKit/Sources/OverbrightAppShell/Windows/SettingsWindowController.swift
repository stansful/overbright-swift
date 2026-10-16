// OverbrightAppShell/Windows/SettingsWindowController.swift — the Settings window. ARCHITECTURE.md §7.6, §10.2; D15.
// Seam written by WP0a (§10.0): `init(services:)` and `show(pane:)` are fixed; WP0b ports Cranny's controller (AppKit
// `NSWindow` + `NSHostingController`, 860 × 620, released on close, ⌘Q and ⌘Z) and WP11 fills the panes.
// The WP0a body opens nothing.
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Owns the Settings window.
final class SettingsWindowController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Shows Settings at `pane` ("pane" or "pane#row", Cranny deep links), or at the last pane when nil.
    /// WP0a seam: logs the request only.
    func show(pane: String?) {
        log.info("Settings requested (\(pane ?? "-", privacy: .public)); the window lands with WP0b")
    }
}
