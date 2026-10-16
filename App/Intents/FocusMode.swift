// App/Intents/FocusMode.swift — the "Overbright" parameter of the Focus filter: Leave Alone, Off, On (DESIGN.md
// §12.8). ARCHITECTURE.md §7.7; D18.
import AppIntents

/// What a Focus does to Overbright. `leaveAlone` is the default and the "no filter" state.
enum FocusMode: String, AppEnum {
    case leaveAlone, off, on

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Overbright"
    static let caseDisplayRepresentations: [FocusMode: DisplayRepresentation] = [
        .leaveAlone: "Leave Alone",
        .off: "Off",
        .on: "On",
    ]
}
