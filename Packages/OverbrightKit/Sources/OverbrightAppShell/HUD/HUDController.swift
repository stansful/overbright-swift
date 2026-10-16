// OverbrightAppShell/HUD/HUDController.swift — the on-screen level indicator. ARCHITECTURE.md §7.6, §10.12; DESIGN.md
// §6; D19. Seam written by WP0a (§10.0): `init(services:)`, `start()` and `stop()` are fixed; WP10 writes the body
// (observe `services.boost.status.lastChange` by its `sequence`, a non-activating capture-excluded panel, never two).
// The WP0a body observes nothing and opens no window.
import OverbrightCore

/// Shows the HUD for level changes from shortcuts, intents, Focus and Back to Standard, "Preparing…" and automation
/// stops.
final class HUDController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Starts observing the engine's `lastChange`. WP0a seam: does nothing.
    func start() {}

    /// Stops observing and closes the HUD. WP0a seam: does nothing.
    func stop() {}
}
