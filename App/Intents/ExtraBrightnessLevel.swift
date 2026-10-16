// App/Intents/ExtraBrightnessLevel.swift — the Level parameter of Set Extra Brightness: a preset or "Multiplier"
// (DESIGN.md §12.8, §1 principle 4: canonical units). ARCHITECTURE.md §7.7; D18.
import AppIntents
import OverbrightCore

/// Indoor, Bright Room, Sunlight, Max, or a light multiplier given in the Multiplier parameter. Raw values match
/// `LevelPreset`'s.
enum ExtraBrightnessLevel: String, AppEnum {
    case indoor, brightRoom, sunlight, max, multiplier

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Level"
    static let caseDisplayRepresentations: [ExtraBrightnessLevel: DisplayRepresentation] = [
        .indoor: "Indoor",
        .brightRoom: "Bright Room",
        .sunlight: "Sunlight",
        .max: "Max",
        .multiplier: "Multiplier",
    ]

    /// The router's request: the preset, or `multiplier` for `.multiplier`.
    func request(multiplier: Double) -> ExtraBrightnessRequest {
        switch self {
        case .indoor: .preset(.indoor)
        case .brightRoom: .preset(.brightRoom)
        case .sunlight: .preset(.sunlight)
        case .max: .preset(.max)
        case .multiplier: .multiplier(multiplier)
        }
    }
}
