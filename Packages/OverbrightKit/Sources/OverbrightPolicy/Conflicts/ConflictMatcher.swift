// OverbrightPolicy/Conflicts/ConflictMatcher.swift — matches a running app against the conflict catalogue.
// ARCHITECTURE.md §3.10, §7.2. Stub until WP1.
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
    /// The catalogue entry `app` matches, as a `ConflictingApp`; nil for no match and for Overbright itself.
    public static func match(_ app: RunningApp, in catalog: [ConflictCatalogEntry], ownBundleID: String)
        -> ConflictingApp? {
        _ = (app, catalog, ownBundleID)
        return nil   // WP1
    }
}
