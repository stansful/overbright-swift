// OverbrightCore/Services/OwnEDRSurfaces.swift — displays on which Overbright's own EDR content is on screen.
// ARCHITECTURE.md §3.9, §4.3 ("pre-held"), D6.
import Observation

/// Displays on which Overbright's OWN EDR content is on screen (Fill Light, the Welcome card, the calibration
/// window). Boost treats them as headroom that is already held (§4.3 "pre-held"), never as idle headroom.
@MainActor @Observable public final class OwnEDRSurfaces {
    /// Number of surfaces held per display.
    public private(set) var displays: [DisplayKey: Int] = [:]
    /// No surface held.
    public init() {}
    /// Call when the surface is ordered in on `display`; cancel the token when it is ordered out.
    public func hold(_ display: DisplayKey) -> ObservationToken {
        displays[display, default: 0] += 1
        return ObservationToken { [weak self] in
            guard let self, let n = self.displays[display] else { return }
            self.displays[display] = n > 1 ? n - 1 : nil
        }
    }
    /// Whether any of our surfaces holds EDR on `display`.
    public func isHeld(_ display: DisplayKey) -> Bool { displays[display] != nil }
}
