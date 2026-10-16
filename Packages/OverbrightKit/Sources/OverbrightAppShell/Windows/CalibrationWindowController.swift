// OverbrightAppShell/Windows/CalibrationWindowController.swift — the calibration window on the display under test.
// ARCHITECTURE.md §7.6, §10.13; DESIGN.md §9. Seam written by WP0a (§10.0): `init(services:)` and `show(display:)`
// are fixed; WP11 writes the body (borderless full screen, black surround, Esc restores at once, registers with
// `OwnEDRSurfaces`). The WP0a body opens nothing.
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Owns the calibration window.
final class CalibrationWindowController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Starts a calibration of `display`. WP0a seam: logs the request only.
    func show(display: DisplayKey) {
        log.info("Calibration requested for \(display.rawValue, privacy: .public); the window lands with WP11")
    }
}
