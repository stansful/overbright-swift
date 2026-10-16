// OverbrightCore/Model/System/ConflictingApp.swift — a running app that matched the catalogue. ARCHITECTURE.md §3.3, §7.2.

/// A running app that matched the catalogue. `displayName` comes from `NSRunningApplication.localizedName`.
public nonisolated struct ConflictingApp: Hashable, Sendable {
    /// The catalogue entry it matched.
    public var entryID: String
    /// The entry's severity.
    public var severity: ConflictSeverity
    /// The app's bundle identifier, if any.
    public var bundleID: String?
    /// The app's process ID.
    public var processID: Int32
    /// The localized name at runtime (never a literal; D3). UI only, `.private` in logs.
    public var displayName: String
    /// A matched app.
    public init(entryID: String, severity: ConflictSeverity, bundleID: String?, processID: Int32, displayName: String) {
        self.entryID = entryID; self.severity = severity; self.bundleID = bundleID
        self.processID = processID; self.displayName = displayName
    }
}
