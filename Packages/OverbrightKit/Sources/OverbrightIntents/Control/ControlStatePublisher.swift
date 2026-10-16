// OverbrightIntents/Control/ControlStatePublisher.swift — the one publish point of the dormant control's state.
// ARCHITECTURE.md §7.7, §10.0 (Intents seam: `init(boost:)`, `start()`, `stop()`); D25.
// Started by the composition root, it observes `BoostControl.status` and, on every change of what the control shows
// (on/off and level), writes the word → the snapshot → reloads the control, in that order, with a new generation.
// `start()` and `stop()` also reload every control, which fixes a stale "on" after a crash (no supported way exists
// to update a control after its app died). A no-op unless the build ships the control (`CONTROLS=1`): zero work in
// the default build. It never reads a display and never writes one.
import Foundation
import Observation
import OverbrightChannel
import OverbrightCore

/// Publishes the engine's on/off state and level to the Control Center control through `OverbrightChannel`.
@MainActor public final class ControlStatePublisher {
    /// Light multiples the word's level spans: per mille of four stops (×16, the highest potential of any Mac display).
    public static let levelSpanStops = 4.0

    private let boost: any BoostControl
    private let outlet: any ControlStateOutlet
    private var observation: ObservationToken?
    private var generation: UInt32 = 0

    /// Whether `start()` found the control and is publishing.
    public private(set) var isPublishing = false

    /// A publisher observing `boost`, writing to the system (notifyd, the app's preferences, Control Center).
    public convenience init(boost: any BoostControl) { self.init(boost: boost, outlet: SystemControlOutlet()) }

    /// A publisher observing `boost`, writing to `outlet` (tests record it).
    public init(boost: any BoostControl, outlet: any ControlStateOutlet) {
        self.boost = boost; self.outlet = outlet
    }

    /// Starts publishing (the composition root calls it): makes the `set=on` token if needed, publishes the current
    /// state, reloads every control, then follows the status. Does nothing when the build has no control.
    public func start() {
        guard !isPublishing, outlet.isControlInstalled else { return }
        isPublishing = true
        outlet.ensureToken()
        publish(Self.content(of: boost.status))
        outlet.reloadAllControls()
        let boost = boost
        observation = observe({ Self.content(of: boost.status) }) { [weak self] content in
            guard let self, self.isPublishing else { return }
            self.publish(content)
            self.outlet.reloadControl()
        }
    }

    /// Stops publishing (at quit): the word and the snapshot become "not valid" (the control shows off) and every
    /// control reloads.
    public func stop() {
        guard isPublishing else { return }
        isPublishing = false
        observation?.cancel()
        observation = nil
        outlet.post(BoostChannel.pack(.invalid))
        outlet.writeSnapshot(.invalid)
        outlet.reloadAllControls()
    }

    /// What the control shows of `status` (generation 0; `publish` stamps it): the master switch and the level.
    public static func content(of status: BoostStatus) -> BoostChannel.State {
        BoostChannel.State(isValid: true, isOn: status.isOn, levelPermille: levelPermille(of: status), generation: 0)
    }

    /// The level in the word: the highest boost target of any display, in stops above Standard, per mille of
    /// `levelSpanStops`; 0 while off, at Standard or dimmed. Targets, not applied gains: a ramp does not publish.
    public static func levelPermille(of status: BoostStatus) -> Int {
        guard status.isOn else { return 0 }
        let gains = status.displays.compactMap { display -> Double? in
            guard case .boost(let gain)? = display.decision?.target, gain.isFinite else { return nil }
            return gain
        }
        guard let gain = gains.max(), gain > 1 else { return 0 }
        let stops = min(log2(gain), levelSpanStops)
        return Int((stops / levelSpanStops * Double(BoostChannel.maximumLevel)).rounded())
    }

    // MARK: Private

    private func publish(_ content: BoostChannel.State) {
        generation &+= 1
        var state = content
        state.generation = generation
        outlet.post(BoostChannel.pack(state))
        outlet.writeSnapshot(state)
    }
}
