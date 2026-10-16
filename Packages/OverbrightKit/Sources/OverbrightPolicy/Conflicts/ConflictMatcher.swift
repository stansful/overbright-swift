// OverbrightPolicy/Conflicts/ConflictMatcher.swift — matches a running app against the conflict catalogue.
// ARCHITECTURE.md §3.10, §7.2, D3. Identifiers only: names are never matched (they are localized), and the UI shows
// `NSRunningApplication.localizedName` at runtime.
import OverbrightCore

/// Conflict matcher (ARCHITECTURE.md §7.2): exact bundle ID (+ "-setapp" twin), vendor prefix, executable name, optional team ID.
public nonisolated enum ConflictMatcher {
    /// A running app as the matcher needs it.
    public struct RunningApp: Hashable, Sendable {
        /// The bundle identifier, if any.
        public var bundleID: String?
        /// The executable's file name (bundle-less tools).
        public var executableName: String?
        /// The code-signing team ID, if read.
        public var teamID: String?
        /// The process ID.
        public var processID: Int32
        /// `NSRunningApplication.localizedName` (becomes `ConflictingApp.displayName`).
        public var localizedName: String
        /// A running app.
        public init(bundleID: String?, executableName: String?, teamID: String?, processID: Int32, localizedName: String) {
            self.bundleID = bundleID; self.executableName = executableName; self.teamID = teamID
            self.processID = processID; self.localizedName = localizedName
        }
    }

    /// Setapp's mandatory bundle-ID suffix: every exact ID also matches its twin.
    public static let setappSuffix = "-setapp"
    /// Characters that may follow a vendor prefix ("com.example.booster" matches "com.example.booster-pro" and
    /// "com.example.booster.2", never the sibling "com.example.boosterx").
    static let prefixBoundaries: Set<Character> = [".", "-", "_"]
    /// Words in the last bundle-ID component of helpers and extensions, which never touch displays. They are
    /// ignored on prefix matches (an exact catalogue ID always matches).
    static let helperMarkers = ["helper", "launcher", "launchatlogin", "loginitem", "widget", "extension", "agent", "xpc"]

    /// The catalogue entry `app` matches, as a `ConflictingApp`; nil for no match and for Overbright itself (our own
    /// bundle ID, helpers and extensions). The first matching entry wins, so a catalogue lists S1 first.
    ///
    /// Rules, case-insensitive as LaunchServices compares bundle IDs: (1) an exact bundle ID or its "-setapp" twin;
    /// (2) a vendor prefix at an identifier boundary, unless the app is a helper or extension, and unless its known
    /// team ID differs from the entry's (the team ID confirms a prefix match; an unread one does not veto it);
    /// (3) an executable name, for bundle-less command-line tools only.
    public static func match(_ app: RunningApp, in catalog: [ConflictCatalogEntry], ownBundleID: String)
        -> ConflictingApp? {
        guard let entry = catalog.first(where: { matches(app, $0, ownBundleID: ownBundleID.lowercased()) }) else {
            return nil
        }
        return ConflictingApp(entryID: entry.id, severity: entry.severity, bundleID: app.bundleID,
                              processID: app.processID, displayName: app.localizedName)
    }

    private static func matches(_ app: RunningApp, _ entry: ConflictCatalogEntry, ownBundleID: String) -> Bool {
        guard let bundleID = app.bundleID?.lowercased(), !bundleID.isEmpty else {
            guard let executable = app.executableName?.lowercased(), !executable.isEmpty else { return false }
            return entry.executableNames.contains { $0.lowercased() == executable }
        }
        if !ownBundleID.isEmpty && (bundleID == ownBundleID || bundleID.hasPrefix(ownBundleID + ".")) { return false }
        let exact = entry.bundleIDs.map { $0.lowercased() }
        if exact.contains(bundleID) || exact.contains(where: { $0 + setappSuffix == bundleID }) { return true }
        guard !isHelper(bundleID) else { return false }
        let prefixed = entry.bundlePrefixes.contains { prefix in hasPrefix(bundleID, prefix.lowercased()) }
        guard prefixed else { return false }
        guard let team = app.teamID, !entry.teamIDs.isEmpty else { return true }
        return entry.teamIDs.contains { $0.uppercased() == team.uppercased() }
    }

    private static func hasPrefix(_ bundleID: String, _ prefix: String) -> Bool {
        guard !prefix.isEmpty, bundleID.hasPrefix(prefix) else { return false }
        let rest = bundleID.dropFirst(prefix.count)
        return rest.first.map(prefixBoundaries.contains) ?? true
    }

    private static func isHelper(_ bundleID: String) -> Bool {
        let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        return helperMarkers.contains { last.contains($0) }
    }
}
