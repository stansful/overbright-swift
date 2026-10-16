// App/Intents/FocusLevel.swift — the Level of the Focus filter (shown with On; DESIGN.md §12.8). ARCHITECTURE.md §7.7;
// D18. Presets only: the filter hands Signals one `FocusDirective.on(level:)` slider position for every display, and
// a multiplier maps to a different position on each display (its own top), so it cannot be said as one position.
import AppIntents
import OverbrightCore

/// Indoor, Bright Room, Sunlight or Max. Raw values match `LevelPreset`'s.
enum FocusLevel: String, AppEnum {
    case indoor, brightRoom, sunlight, max

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Level"
    static let caseDisplayRepresentations: [FocusLevel: DisplayRepresentation] = [
        .indoor: "Indoor",
        .brightRoom: "Bright Room",
        .sunlight: "Sunlight",
        .max: "Max",
    ]

    /// The preset.
    var preset: LevelPreset {
        switch self {
        case .indoor: .indoor
        case .brightRoom: .brightRoom
        case .sunlight: .sunlight
        case .max: .max
        }
    }
}
