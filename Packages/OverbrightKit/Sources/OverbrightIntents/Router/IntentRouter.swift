// OverbrightIntents/Router/IntentRouter.swift — the router behind the app target's App Intents adapters.
// ARCHITECTURE.md §3.11, §7.7, §10.0 (Intents seam), §10.10; D18.
// Seam written by WP0a: the no-argument initializer, `connect(boost:displays:signals:)`, one method per intent and
// `focus(_:)` are fixed. The WP0a bodies forward to the engine at once; WP8 owns the file and adds the readiness wait
// (≤ 5 s for `BoostStatus.isReady`), the launch-policy override, display checks and localized errors.
import Foundation
import OverbrightCore

/// Routes the one-line intent adapters in `App/Intents/` to the engine. `OverbrightApp.init` creates it with no
/// arguments and registers it with `AppDependencyManager`, so an intent that launches the app can resolve it before
/// `applicationDidFinishLaunching`; the composition root connects it once the services exist.
@MainActor
public final class IntentRouter {
    private var boost: (any BoostControl)?
    private var displays: (any DisplayDirectory)?
    private var signals: (any SystemSignals)?
    private var pendingFocus: FocusDirective?

    /// Creates an unconnected router.
    public init() {}

    /// Whether the composition root has connected the router.
    public var isConnected: Bool { boost != nil }

    /// Connects the router to the engine, the display directory and the Focus sink (called once, by the composition
    /// root). A Focus directive that arrived earlier is delivered now.
    public func connect(boost: any BoostControl, displays: any DisplayDirectory, signals: any SystemSignals) {
        self.boost = boost; self.displays = displays; self.signals = signals
        if let directive = pendingFocus {
            pendingFocus = nil
            signals.setFocusDirective(directive)
        }
    }

    // MARK: One method per intent (DESIGN.md §12.8)

    /// Turn Overbright On or Off.
    public func toggle() async throws { try engine().toggle(source: .intent) }

    /// Turn On Overbright.
    public func turnOn() async throws { try engine().setOn(true, source: .intent) }

    /// Turn Off Overbright.
    public func turnOff() async throws { try engine().setOn(false, source: .intent) }

    /// Set Extra Brightness: a preset or a multiplier, for `display` or every display (nil).
    public func setExtraBrightness(_ request: ExtraBrightnessRequest, display: DisplayKey?) async throws {
        let boost = try engine()
        try requireConnected(display)
        boost.setExtraBrightness(request, for: display, source: .intent)
    }

    /// Dim Displays: `percent` (2 … 99) of Standard light, for `display` or every display that can dim (nil).
    public func dim(percent: Int, display: DisplayKey?) async throws {
        let boost = try engine()
        try requireConnected(display)
        boost.setDimLight(Double(min(max(percent, 2), 99)) / 100, for: display, source: .intent)
    }

    /// Pause Overbright for `duration`.
    public func pause(for duration: Duration) async throws {
        let boost = try engine()
        boost.pause(until: Date().addingTimeInterval(duration.timeInterval), source: .intent)
    }

    /// Resume Overbright.
    public func resume() async throws { try engine().resume(source: .intent) }

    /// Get Overbright State: the engine's status (the adapter words the dialog).
    public func state() async throws -> BoostStatus { try engine().status }

    /// Back to Standard.
    public func returnToStandard() async throws { try engine().returnToStandard(source: .intent) }

    /// The Focus filter's directive, handed to `SystemSignals.setFocusDirective(_:)` (kept until the router is
    /// connected).
    public func focus(_ directive: FocusDirective) {
        if let signals { signals.setFocusDirective(directive) } else { pendingFocus = directive }
    }

    // MARK: Private

    private func engine() throws -> any BoostControl {
        guard let boost, boost.status.isReady else { throw IntentRouterError.notReady }
        return boost
    }

    private func requireConnected(_ display: DisplayKey?) throws {
        guard let display else { return }
        guard displays?.facts(for: display) != nil else { throw IntentRouterError.displayNotConnected }
    }
}
