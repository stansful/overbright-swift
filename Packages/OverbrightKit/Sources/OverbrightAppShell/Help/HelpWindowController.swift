// OverbrightAppShell/Help/HelpWindowController.swift — the local Help window. ARCHITECTURE.md §7.6, §10.12;
// DESIGN.md §12.6. Seam written by WP0a (§10.0): `init(services:)` and `show(anchor:)` are fixed; WP10 writes the body
// (a small `NSWindow` hosting PanelUI's `HelpView`, scrolled to the anchor). The WP0a body opens nothing.
import OverbrightCore
import os

private let log = Log.logger(.panel)

/// Owns the Help window.
final class HelpWindowController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Shows Help, scrolled to `anchor` ("no-extra-range", "control-center", …). WP0a seam: logs the request only.
    func show(anchor: String?) {
        log.info("Help requested (\(anchor ?? "-", privacy: .public)); the window lands with WP10")
    }
}
