// OverbrightChannel/BoostChannel.swift — the out-of-process state of the dormant control, without an App Group.
// ARCHITECTURE.md §7.7, §10.0 (Channel seam); D25. Foundation only, nonisolated: the extension links nothing else.
// Seam written by WP0a: the names are fixed; WP8 writes the bodies (the bit layout of the notify word, the
// CFPreferences snapshot read by the extension, the token). The WP0a bodies report "not valid" everywhere, which the
// extension shows as off.
import Foundation

/// Pack and unpack of the notifyd state word, the preferences snapshot and the `set=on` token.
public enum BoostChannel {
    /// The notifyd name the app posts and the extension reads.
    public static let notifyName = "app.overbright.Overbright.state"

    /// What the word carries: valid bit, on, level in per mille, generation.
    public struct State: Hashable, Sendable {
        /// False when no app wrote the word (or the app is not running): the control shows off.
        public var isValid: Bool
        /// The master switch.
        public var isOn: Bool
        /// The level shown by the control, 0 … 1000.
        public var levelPermille: Int
        /// Increases with every publish.
        public var generation: UInt32
        /// A state.
        public init(isValid: Bool, isOn: Bool, levelPermille: Int, generation: UInt32) {
            self.isValid = isValid; self.isOn = isOn; self.levelPermille = levelPermille; self.generation = generation
        }
        /// No state: the control shows off.
        public static let invalid = State(isValid: false, isOn: false, levelPermille: 0, generation: 0)
    }

    /// The 64-bit notify word of `state`. WP0a seam: 0 (not valid).
    public static func pack(_ state: State) -> UInt64 { 0 }

    /// The state in a notify word. WP0a seam: always `.invalid`.
    public static func unpack(_ word: UInt64) -> State { .invalid }

    /// The preferences snapshot the extension reads (read-only shared preference). WP0a seam: none.
    public static func readSnapshot() -> State? { nil }

    /// Writes the preferences snapshot (app only). WP0a seam: writes nothing.
    public static func writeSnapshot(_ state: State) {}

    /// A new random token for `overbright://control?set=on` (kept in the app's own preferences). WP0a seam: empty.
    public static func makeToken() -> String { "" }
}
