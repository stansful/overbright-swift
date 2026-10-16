// OverbrightCore/Model/Policy/PausedAppRule.swift — one per-app pause rule. ARCHITECTURE.md §3.4, §6.5, D10.

/// A per-app pause rule (D10, ARCHITECTURE.md §6.5). Matches the exact bundle ID, case-insensitively.
public nonisolated struct PausedAppRule: Hashable, Codable, Sendable {
    /// When the rule applies.
    public enum Mode: String, Codable, Sendable {
        /// While the app is frontmost (on the displays that show its window).
        case whileFrontmost
        /// While the app holds a display-sleep assertion (playing video), beta until H-P1.
        case whilePlaying
    }
    /// The app's bundle identifier.
    public var bundleID: String
    /// When the rule applies.
    public var mode: Mode
    /// The rule is on.
    public var isEnabled: Bool
    /// A rule, on by default.
    public init(bundleID: String, mode: Mode, isEnabled: Bool = true) {
        self.bundleID = bundleID; self.mode = mode; self.isEnabled = isEnabled
    }
}
