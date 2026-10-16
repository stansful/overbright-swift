// OverbrightCore/Fakes/PreviewFillLightControl.swift — an in-memory FillLightControl. ARCHITECTURE.md §3.9.
import Observation

/// A `FillLightControl` with in-memory state and recorded calls.
@MainActor @Observable public final class PreviewFillLightControl: FillLightControl {
    /// The edge light shows.
    public var isOn: Bool
    /// Turned on by the camera rule.
    public var isAutomatic: Bool
    /// Every call, in order ("setOn(true,panel)").
    public private(set) var calls: [String] = []
    /// Off by default.
    public init(isOn: Bool = false, isAutomatic: Bool = false) { self.isOn = isOn; self.isAutomatic = isAutomatic }
    /// Sets `isOn`; a manual change ends the automatic state.
    public func setOn(_ on: Bool, source: ControlSource) {
        calls.append("setOn(\(on),\(source.rawValue))")
        isOn = on
        isAutomatic = false
    }
}
