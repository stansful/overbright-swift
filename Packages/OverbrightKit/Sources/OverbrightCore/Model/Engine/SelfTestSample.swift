// OverbrightCore/Model/Engine/SelfTestSample.swift — one 10 Hz self-test sample. ARCHITECTURE.md §3.5, §8.4.

/// One self-test sample (10 Hz) or event line.
public nonisolated struct SelfTestSample: Hashable, Codable, Sendable {
    /// Seconds since the strategy was armed.
    public var seconds: Double
    /// Granted headroom.
    public var current: Double
    /// Potential headroom.
    public var potential: Double
    /// Table factor at the time (1 during a self-test).
    public var appliedFactor: Double
    /// A journal code when the sample marks an event.
    public var event: String?
    /// A sample.
    public init(seconds: Double, current: Double, potential: Double, appliedFactor: Double, event: String?) {
        self.seconds = seconds; self.current = current; self.potential = potential
        self.appliedFactor = appliedFactor; self.event = event
    }
}
