// OverbrightFillLight/Rule/FillLightRule.swift — on/off and the camera rule as a pure state machine.
// ARCHITECTURE.md §10.9 (FillLightRuleTests), §7.1 (Signals debounces `isCameraInUse` 1 s on / 3 s off); DESIGN.md
// §7.7 ("Turn on while a camera is in use"), §11 (camera rule).
import OverbrightCore

/// Whether the Fill Light is on, and the camera rule (DESIGN.md §11): on `onDelay` after a matching camera starts,
/// off `offDelay` after the last one stops; turning it off by hand while a camera runs keeps it off until the camera
/// stops. Pure: the controller feeds it the camera signal, manual changes and the time, and sleeps until
/// `nextDeadline`, then calls `advance(to:)`.
///
/// Rules beyond DESIGN.md, chosen so the light never changes behind the user's back:
/// - only a light the rule turned on (`isAutomatic`) is turned off by the camera stopping; a light the user turned on
///   stays on, even if a call started and ended meanwhile;
/// - turning the rule on while a camera already runs counts as the camera starting now;
/// - turning the rule off leaves the light as it is, now as the user's own (it no longer goes off with the camera);
/// - a camera that stops within `onDelay` never counted as started (apps switching devices open and close it briefly).
public nonisolated struct FillLightRule: Hashable, Sendable {
    /// The camera rule's delays.
    public nonisolated struct Timing: Hashable, Sendable {
        /// From a camera starting to the light turning on.
        public var onDelay: Duration
        /// From the last camera stopping to the light turning off.
        public var offDelay: Duration
        /// Delays (zero is allowed).
        public init(onDelay: Duration, offDelay: Duration) { self.onDelay = onDelay; self.offDelay = offDelay }
        /// 1 s on, 3 s off (DESIGN.md §11), for a raw camera signal.
        public static let standard = Timing(onDelay: FillLightTiming.cameraOnDelay, offDelay: FillLightTiming.cameraOffDelay)
        /// No delays: Signals publishes `isCameraInUse` already debounced by `standard`'s amounts (§7.1), so the
        /// rule acts at once (`FillLightController`'s default; one debounce, not two).
        public static let signalsDebounced = Timing(onDelay: .zero, offDelay: .zero)
    }

    private nonisolated enum Pending: Hashable, Sendable {
        case cameraStarts(at: MonotonicInstant)
        case cameraStops(at: MonotonicInstant)
    }

    /// The delays this rule applies.
    public let timing: Timing
    /// The light should show.
    public private(set) var isOn = false
    /// The camera rule turned it on (and will turn it off when the camera stops).
    public private(set) var isAutomatic = false
    /// "Turn on while a camera is in use" (`FillLightSettings.autoWithCamera`).
    public private(set) var followsCamera = false
    /// The raw signal (`SystemSnapshot.isCameraInUse`).
    public private(set) var isCameraRunning = false
    /// A camera has run for `onDelay` and has not been stopped for `offDelay`: a call is going on.
    public private(set) var isCameraSessionActive = false
    /// The user turned the light off while a camera ran: no automatic On until the camera stops.
    public private(set) var isSuppressed = false
    private var pending: Pending?

    /// Off, not following the camera.
    public init(timing: Timing = .standard) { self.timing = timing }

    /// When `advance(to:)` has something to do next; nil = nothing pending (no task needs to run).
    public var nextDeadline: MonotonicInstant? {
        switch pending {
        case .cameraStarts(let at), .cameraStops(let at): at
        case nil: nil
        }
    }

    /// The user (panel, menu, Settings, shortcut, intent) turns the light on or off. Off while a followed camera runs
    /// suppresses the rule until the camera stops; On ends that suppression.
    public mutating func setManually(_ on: Bool) {
        isOn = on
        isAutomatic = false
        isSuppressed = !on && followsCamera && (isCameraRunning || isCameraSessionActive)
    }

    /// "Turn on while a camera is in use" changed.
    public mutating func setFollowsCamera(_ follows: Bool, now: MonotonicInstant) {
        guard follows != followsCamera else { return }
        followsCamera = follows
        if follows {
            if isCameraRunning { pending = .cameraStarts(at: now + timing.onDelay) }
        } else {
            pending = nil
            isCameraSessionActive = false
            isSuppressed = false
            isAutomatic = false
        }
    }

    /// The camera signal changed (`running`: some matching camera runs).
    public mutating func cameraChanged(running: Bool, now: MonotonicInstant) {
        guard running != isCameraRunning else { return }
        isCameraRunning = running
        guard followsCamera else { return }
        if running {
            // Back within `offDelay`: the call goes on and nothing is pending; otherwise the camera starts now.
            pending = isCameraSessionActive ? nil : .cameraStarts(at: now + timing.onDelay)
        } else if isCameraSessionActive {
            pending = .cameraStops(at: now + timing.offDelay)
        } else {
            pending = nil
            isSuppressed = false
        }
    }

    /// Applies the pending transition if its deadline has passed.
    public mutating func advance(to now: MonotonicInstant) {
        guard let pending, let deadline = nextDeadline, deadline <= now else { return }
        self.pending = nil
        switch pending {
        case .cameraStarts:
            isCameraSessionActive = true
            if !isSuppressed && !isOn {
                isOn = true
                isAutomatic = true
            }
        case .cameraStops:
            isCameraSessionActive = false
            isSuppressed = false
            if isAutomatic {
                isOn = false
                isAutomatic = false
            }
        }
    }
}
