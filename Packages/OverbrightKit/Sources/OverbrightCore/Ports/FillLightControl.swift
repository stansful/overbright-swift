// OverbrightCore/Ports/FillLightControl.swift — the Fill Light façade (implemented by OverbrightFillLight).
// ARCHITECTURE.md §3.6, D12.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// Fill Light on or off.
@MainActor public protocol FillLightControl: AnyObject, Observable {
    /// The edge light shows.
    var isOn: Bool { get }
    /// Turned on by the camera rule.
    var isAutomatic: Bool { get }
    /// Turns the edge light on or off.
    func setOn(_ on: Bool, source: ControlSource)
}
