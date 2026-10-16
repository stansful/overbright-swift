// OverbrightAppShell/HUD/LowLevelPromptController.swift — "Keep this level?". ARCHITECTURE.md §4.9, §7.6, §10.12;
// DESIGN.md §6. Seam written by WP0a (§10.0): `init(services:)`, `start()` and `stop()` are fixed; WP10 writes the
// body (observe `status.pendingLowLevel`, a non-activating panel in the HUD's place that can become key; the revert
// itself is the engine's deadline). The WP0a body observes nothing and opens no window.
import OverbrightCore

/// Shows the Keep-this-level prompt while the engine has a pending low-level confirmation.
final class LowLevelPromptController {
    private let services: OverbrightServices

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Starts observing `status.pendingLowLevel`. WP0a seam: does nothing.
    func start() {}

    /// Stops observing and closes the prompt. WP0a seam: does nothing.
    func stop() {}
}
