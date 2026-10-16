// OverbrightIntents/Control/ControlStatePublisher.swift — the one publish point of the dormant control's state.
// ARCHITECTURE.md §7.7, §10.0 (Intents seam); D25. Seam written by WP0a: `init(boost:)`, `start()` and `stop()` are
// fixed; WP8 writes the body (observe `BoostControl.status`, write the notify word, the preferences snapshot and
// reload the control; `reloadAllControls()` at launch and quit). A no-op unless the control ships (`CONTROLS=1`).
import OverbrightCore

/// Publishes the engine's on/off state and level to the Control Center control through `OverbrightChannel`.
public final class ControlStatePublisher {
    private let boost: any BoostControl

    /// A publisher observing `boost`.
    public init(boost: any BoostControl) { self.boost = boost }

    /// Starts publishing (the composition root calls it). WP0a seam: does nothing.
    public func start() {}

    /// Stops publishing (at quit). WP0a seam: does nothing.
    public func stop() {}
}
