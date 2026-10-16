// OverbrightCore/Model/Displays/LevelPreset.swift — named stops on the boost half. ARCHITECTURE.md §3.2, §5.3.

/// Named stops on the boost half (slider ticks). Raw values are persisted; never rename.
/// A preset is hidden on a display when its gain is below ×1.1 or within 0.1 stop of the next kept one (§5.3).
public nonisolated enum LevelPreset: String, Codable, Sendable, CaseIterable {
    /// The detent (0).
    case standard
    /// 0.25 of the boost half.
    case indoor
    /// 0.5 of the boost half (the default level of a newly enabled display).
    case brightRoom
    /// 0.75 of the boost half.
    case sunlight
    /// The top of the boost half.
    case max
    /// Where the preset sits on the slider.
    public var position: LevelPosition {
        switch self {
        case .standard: .standard
        case .indoor: LevelPosition(0.25)
        case .brightRoom: LevelPosition(0.5)
        case .sunlight: LevelPosition(0.75)
        case .max: LevelPosition(1)
        }
    }
}
