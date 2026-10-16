// OverbrightCore/Model/Displays/TriggerPixel.swift — the pixel value a trigger shows. ARCHITECTURE.md §3.2, §4.7.

/// Pixel value the trigger shows (ARCHITECTURE.md §4.7).
public nonisolated enum TriggerPixel: String, Codable, Sendable {
    /// 0.0 (T1: tag only).
    case black
    /// 1.0 (lab only; not in the default ladder).
    case sdrWhite
    /// 1.6.
    case bright
    /// The extended-range component value drawn.
    public var rawComponent: Double {
        switch self { case .black: 0; case .sdrWhite: 1; case .bright: 1.6 }
    }
}
