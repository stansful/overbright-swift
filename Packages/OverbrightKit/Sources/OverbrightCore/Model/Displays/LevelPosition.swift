// OverbrightCore/Model/Displays/LevelPosition.swift — the one per-display slider value. ARCHITECTURE.md §3.2, §5.3, D11.

/// The one continuous per-display control (D11): −1 … 0 dims, 0 is the Standard detent, 0 … 1 boosts.
/// Boost half: linear in stops of the display's top. Dim half: stops = log₂(50) × |p|^2.5 (gentle near the detent).
/// ARCHITECTURE.md §5.3.
public nonisolated struct LevelPosition: Hashable, Comparable, Codable, Sendable {
    /// −1 … 1; 0 is Standard.
    public var value: Double
    /// A position clamped to −1 … 1 (non-finite input becomes Standard).
    public init(_ value: Double) { self.value = min(max(value.isFinite ? value : 0, -1), 1) }
    /// The detent: no boost, no dimming.
    public static let standard = LevelPosition(0)
    /// Lower positions sort first.
    public static func < (a: Self, b: Self) -> Bool { a.value < b.value }
    /// On the boost half (right of the detent).
    public var isBoost: Bool { value > 0 }
    /// On the dim half (left of the detent).
    public var isDim: Bool { value < 0 }
}
