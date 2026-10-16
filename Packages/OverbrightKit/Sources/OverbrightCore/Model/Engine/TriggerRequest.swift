// OverbrightCore/Model/Engine/TriggerRequest.swift — one rung of the ladder as the factory sees it. ARCHITECTURE.md §3.5, §4.7.

/// One rung of the ladder as the factory sees it.
public nonisolated struct TriggerRequest: Hashable, Sendable {
    /// The strategy (T1–T4).
    public var strategy: TriggerStrategy
    /// The pixel shown.
    public var pixel: TriggerPixel
    /// Where the window sits.
    public var placement: TriggerPlacement
    /// How the pixel is composited.
    public var blend: TriggerBlend
    /// Window edge in points (1 pt = 2 × 2 px on Retina).
    public var edgePoints: Double
    /// Headroom tag for tagged strategies (policy A: the display's potential; clamped to ≥ 1.01 by T1).
    public var headroomTag: Double
    /// A request; the window is 1 pt by default.
    public init(strategy: TriggerStrategy, pixel: TriggerPixel, placement: TriggerPlacement, blend: TriggerBlend,
                edgePoints: Double = 1, headroomTag: Double) {
        self.strategy = strategy; self.pixel = pixel; self.placement = placement; self.blend = blend
        self.edgePoints = edgePoints; self.headroomTag = headroomTag
    }
}
