// OverbrightCore/Fakes/PreviewShortcutCenter.swift — an in-memory ShortcutCenter. ARCHITECTURE.md §3.9, D17.
import Observation

/// A `ShortcutCenter` holding bindings in memory (the catalog defaults, none since 2026-10-20, unless a test or preview
/// passes its own). `displayString` renders key caps with a US layout (the real center uses the current keyboard
/// layout).
@MainActor @Observable public final class PreviewShortcutCenter: ShortcutCenter {
    /// The bindings (nil = cleared).
    public private(set) var bindings: [ShortcutID: KeyCombo?]
    /// Shortcuts that report `.conflict` (another app owns the combo).
    public var conflicting: Set<ShortcutID> = []
    /// The recorder is listening.
    public private(set) var isRecording = false

    /// The catalog defaults (`ShortcutCatalog.all`: every shortcut unbound, D17).
    public init() {
        bindings = Dictionary(uniqueKeysWithValues: ShortcutCatalog.all.map { ($0.id, $0.defaultCombo) })
    }

    /// `bindings` over the catalog defaults (a shortcut without an entry keeps its default).
    public convenience init(bindings: [ShortcutID: KeyCombo?]) {
        self.init()
        self.bindings.merge(bindings) { _, new in new }
    }

    /// The state of one shortcut.
    public func state(_ id: ShortcutID) -> ShortcutState {
        guard let binding = bindings[id], let combo = binding else { return .off }
        return conflicting.contains(id) ? .conflict(combo) : .registered(combo)
    }
    /// Stores `combo` (nil clears it).
    @discardableResult public func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState {
        bindings[id] = .some(combo)
        return state(id)
    }
    /// Records the recorder's state.
    public func setRecording(_ recording: Bool) { isRecording = recording }
    /// US key caps of a registered shortcut ("⌃⌥⌘B"); nil when off or in conflict.
    public func displayString(_ id: ShortcutID) -> String? {
        guard case .registered(let combo) = state(id) else { return nil }
        return Self.usKeyCaps(combo)
    }

    /// Key caps in the US layout, modifiers in Apple's order (⌃⌥⇧⌘).
    static func usKeyCaps(_ combo: KeyCombo) -> String {
        var text = ""
        if combo.modifiers.contains(.control) { text += "⌃" }
        if combo.modifiers.contains(.option) { text += "⌥" }
        if combo.modifiers.contains(.shift) { text += "⇧" }
        if combo.modifiers.contains(.command) { text += "⌘" }
        return text + (keys[combo.keyCode] ?? "#\(combo.keyCode)")
    }

    /// kVK_ANSI_* positions in the US layout, plus the named keys.
    private static let keys: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W",
        14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥",
        49: "Space", 50: "`", 51: "⌫", 53: "⎋", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
