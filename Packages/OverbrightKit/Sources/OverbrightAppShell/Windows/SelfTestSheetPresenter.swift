// OverbrightAppShell/Windows/SelfTestSheetPresenter.swift — Advanced ▸ Run Self-Test… ARCHITECTURE.md §8.4, §10.13;
// DESIGN.md §10. Seam written by WP0a (§10.0): `init(services:)` and `present(over:)` are fixed; WP11 writes the sheet
// (consent, progress, results table, Save, Copy). The WP0a body presents nothing.
import AppKit
import OverbrightCore
import os

private let log = Log.logger(.selfTest)

/// Presents the self-test sheet over a window (Settings), or as its own window.
final class SelfTestSheetPresenter {
    private let services: OverbrightServices

    /// A presenter for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Presents the sheet over `window` (nil: its own window). WP0a seam: logs the request only.
    func present(over window: NSWindow?) {
        log.info("Self-test requested; the sheet lands with WP11")
    }
}
