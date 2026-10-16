// OverbrightCore/Model/App/StepSize.swift — the Brighter / Less Bright step. ARCHITECTURE.md §3.8, §5.3.

/// Brighter / Less Bright step, in STOPS of light (§5.3). Arrow keys always move 1/12 stop.
public nonisolated enum StepSize: String, Codable, Sendable, CaseIterable {
    /// ¼ stop (≈ 19 % light).
    case regular
    /// 1/12 stop (≈ 6 % light).
    case fine
    /// The step in stops of light.
    public var stops: Double { self == .regular ? 0.25 : 1.0 / 12 }
}
