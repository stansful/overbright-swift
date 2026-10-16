// OverbrightCore/Model/System/PowerState.swift — power source, battery and Low Power Mode. ARCHITECTURE.md §3.3, §7.1.

/// Power facts the battery and Low Power guards need.
public nonisolated struct PowerState: Hashable, Sendable {
    /// Where power comes from.
    public var source: PowerSourceKind
    /// 0…100; nil on Macs without a battery. Read synchronously whenever the boost turns on (§7.1), so it is never stale.
    public var batteryPercent: Int?
    /// `ProcessInfo.isLowPowerModeEnabled`.
    public var isLowPowerMode: Bool
    /// A power state.
    public init(source: PowerSourceKind, batteryPercent: Int?, isLowPowerMode: Bool) {
        self.source = source; self.batteryPercent = batteryPercent; self.isLowPowerMode = isLowPowerMode
    }
}
