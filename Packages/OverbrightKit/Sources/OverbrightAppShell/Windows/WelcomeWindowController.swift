// OverbrightAppShell/Windows/WelcomeWindowController.swift — the Welcome window. ARCHITECTURE.md §7.6, §10.2; D16.
// Seam written by WP0a (§10.0): `init(services:)` and `show(step:)` are fixed; WP0b ports Cranny's controller
// (640 × 480, container view around the hosting view, close counts as Skip) and WP12 fills the steps.
// The WP0a body has no window: it shows the panel instead, so a launch is never silent (D13).
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Owns the Welcome window.
final class WelcomeWindowController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Shows Welcome at `step` (a step identifier of the Onboarding module), or at the first unfinished step.
    /// WP0a seam: Welcome does not exist yet, so the panel opens instead.
    func show(step: String?) {
        log.info("Welcome requested (\(step ?? "-", privacy: .public)); showing the panel until WP0b/WP12")
        services.app?.showPanel()
    }
}
