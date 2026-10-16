// OverbrightAppShell/Services/ControlStateService.swift — the controls publish point as an ordered service.
// ARCHITECTURE.md §7.7 (one publish point, started by the composition root; `reloadAllControls()` at launch and quit),
// §10.15 (the "Intents" place in the lifecycle, right before Boost), D25.
//
// `ControlStatePublisher` does nothing unless the build ships the control (CONTROLS=1). Under `--qa-simulate` the
// composition root hands it `QuietControlOutlet`, so a QA run never writes the real channel (notifyd word, the app's
// preferences, Control Center), whatever the build (WP8's open item).
import OverbrightChannel
import OverbrightCore
import OverbrightIntents

/// Starts and stops the control's publish point with the other services.
final class ControlStateService: ServiceLifecycle {
    /// The publish point.
    let publisher: ControlStatePublisher

    /// A service over `boost`, publishing to `outlet`.
    init(boost: any BoostControl, outlet: any ControlStateOutlet) {
        publisher = ControlStatePublisher(boost: boost, outlet: outlet)
    }

    /// "Intents".
    var serviceName: String { "Intents" }
    /// Publishes the state and reloads every control (no-op without the control).
    func start() async { publisher.start() }
    /// Marks the state invalid and reloads every control.
    func stop() async { publisher.stop() }
    /// The same, synchronously.
    func stopNow() { publisher.stop() }
}
