// App/Intents/DisplayEntity.swift — the Display parameter of Set Extra Brightness and Dim Displays (DESIGN.md §12.8:
// "Display", plural "Displays", empty = "All Displays"). ARCHITECTURE.md §7.7; D8 (keyed by `DisplayKey`, the name is
// for presentation only), D18.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// A display in the Shortcuts app, identified by its `DisplayKey`; "All Displays" is an entity of its own, so the
/// summary reads "Set extra brightness of All Displays to Bright Room".
struct DisplayEntity: AppEntity {
    /// No `numericFormat` (the plural): every Display parameter takes one value, and the extracted metadata keys a
    /// numeric format as "${int} Displays" while the compiler extracts "%lld Displays", so one of them could never be
    /// localized.
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Display"
    static let defaultQuery = DisplayQuery()

    /// The identifier of "All Displays" (never a display UUID).
    static let allDisplaysID = "all-displays"
    /// Every display.
    static let allDisplays = DisplayEntity(id: allDisplaysID, name: nil)

    /// The display's UUID string, or `allDisplaysID`.
    let id: String
    /// The display's name while it is online (presentation only).
    let name: String?

    var displayRepresentation: DisplayRepresentation {
        if id == Self.allDisplaysID { return DisplayRepresentation(title: "All Displays") }
        guard let name else { return DisplayRepresentation(title: "Display") }
        return DisplayRepresentation(title: "\(name)")
    }

    /// The display the router acts on; nil for every display.
    var key: DisplayKey? { id == Self.allDisplaysID ? nil : DisplayKey(rawValue: id) }

    /// The entity of a router choice.
    init(_ choice: DisplayChoice) { self.init(id: choice.key.rawValue, name: choice.name) }

    private init(id: String, name: String?) { self.id = id; self.name = name }
}
