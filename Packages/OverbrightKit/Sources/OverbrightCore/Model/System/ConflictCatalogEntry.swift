// OverbrightCore/Model/System/ConflictCatalogEntry.swift — one entry of the conflict catalogue. ARCHITECTURE.md §3.3, §7.2.

/// One catalogue entry. Holds identifiers only, never a product name (D3).
public nonisolated struct ConflictCatalogEntry: Hashable, Sendable {
    /// Stable entry ID (persisted in `AdvancedSettings.alwaysContinue`).
    public var id: String
    /// The severity class.
    public var severity: ConflictSeverity
    /// Exact bundle IDs (a "-setapp" twin matches too).
    public var bundleIDs: [String]
    /// Vendor bundle-ID prefixes.
    public var bundlePrefixes: [String]
    /// Executable names of bundle-less tools.
    public var executableNames: [String]
    /// Optional code-signing team IDs.
    public var teamIDs: [String]
    /// An entry; only `id`, `severity` and `bundleIDs` are required.
    public init(id: String, severity: ConflictSeverity, bundleIDs: [String], bundlePrefixes: [String] = [],
                executableNames: [String] = [], teamIDs: [String] = []) {
        self.id = id; self.severity = severity; self.bundleIDs = bundleIDs
        self.bundlePrefixes = bundlePrefixes; self.executableNames = executableNames; self.teamIDs = teamIDs
    }
}
