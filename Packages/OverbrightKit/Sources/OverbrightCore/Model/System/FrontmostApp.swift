// OverbrightCore/Model/System/FrontmostApp.swift — the frontmost app as the guards need it. ARCHITECTURE.md §3.3, §6.5.

/// The frontmost app as the guards need it. `bundleID` is matched exactly; names are never matched.
public nonisolated struct FrontmostApp: Hashable, Sendable {
    /// The app's bundle identifier (nil for bundle-less processes).
    public var bundleID: String?
    /// The app's process ID.
    public var processID: Int32
    /// Displays that show this app's topmost layer-0 window (empty: menu bar only).
    public var displays: Set<DisplayKey>
    /// Holds a display-sleep power assertion (playing video or presenting); nil when unknown.
    public var isPlaying: Bool?
    /// `LSApplicationCategoryType` is games (and not a launcher).
    public var isGame: Bool
    /// A frontmost app.
    public init(bundleID: String?, processID: Int32, displays: Set<DisplayKey>, isPlaying: Bool?, isGame: Bool) {
        self.bundleID = bundleID; self.processID = processID; self.displays = displays
        self.isPlaying = isPlaying; self.isGame = isGame
    }
}
