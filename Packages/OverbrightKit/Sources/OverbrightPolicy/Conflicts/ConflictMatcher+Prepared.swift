// OverbrightPolicy/Conflicts/ConflictMatcher+Prepared.swift — the conflict matcher over a catalogue normalized once.
// ARCHITECTURE.md §7.2, D3. Energy (DESIGN.md §17): `ConflictMatcher.match` lowercases every entry's identifiers, its
// `-setapp` twins and our own bundle ID for every app it is asked about (≈ 150 µs per app with the real catalogue,
// ≈ 14 ms for a running list of 90–100 apps). `Prepared` does that once: exact IDs and their twins and the executable
// names become dictionaries to the first entry that lists them, the prefixes a short list in catalogue order, the team
// IDs uppercased sets; an app then costs one lowercasing and a few lookups. Its answers are the as-built matcher's
// (`ConflictMatcherPreparedTests`, a seeded property test), which stays as the reference.
import OverbrightCore

extension ConflictMatcher {
    /// A catalogue and our own bundle ID normalized once: `match(_:)` returns exactly what
    /// `ConflictMatcher.match(_:in:ownBundleID:)` returns for the same catalogue and own ID.
    public struct Prepared: Sendable {
        /// One vendor prefix, lowercased, with its entry's position in the catalogue.
        private struct Prefix: Sendable {
            var prefix: String
            var entry: Int
            var namesTeams: Bool
        }

        private let catalog: [ConflictCatalogEntry]
        /// Lowercased exact bundle IDs and their `-setapp` twins → the first entry that lists one.
        private let exact: [String: Int]
        /// Lowercased vendor prefixes in catalogue order.
        private let prefixes: [Prefix]
        /// Lowercased executable names → the first entry that lists one.
        private let executables: [String: Int]
        /// Each entry's team IDs, uppercased (empty: the entry confirms nothing by team).
        private let teams: [Set<String>]
        /// Our own bundle ID, lowercased; empty when none was given.
        private let own: String
        /// `own` plus ".": the start of our helpers' and extensions' IDs.
        private let ownChild: String

        /// Normalizes `catalog` (most severe first, as `ConflictMatcher.match` expects) and `ownBundleID` once.
        public init(catalog: [ConflictCatalogEntry], ownBundleID: String) {
            var exact: [String: Int] = [:], executables: [String: Int] = [:]
            var prefixes: [Prefix] = []
            for (index, entry) in catalog.enumerated() {
                for bundleID in entry.bundleIDs {
                    let lowered = bundleID.lowercased()
                    if exact[lowered] == nil { exact[lowered] = index }
                    if exact[lowered + ConflictMatcher.setappSuffix] == nil {
                        exact[lowered + ConflictMatcher.setappSuffix] = index
                    }
                }
                let namesTeams = !entry.teamIDs.isEmpty
                for prefix in entry.bundlePrefixes {
                    prefixes.append(Prefix(prefix: prefix.lowercased(), entry: index, namesTeams: namesTeams))
                }
                for name in entry.executableNames where executables[name.lowercased()] == nil {
                    executables[name.lowercased()] = index
                }
            }
            self.catalog = catalog
            self.exact = exact
            self.prefixes = prefixes
            self.executables = executables
            teams = catalog.map { Set($0.teamIDs.map { $0.uppercased() }) }
            own = ownBundleID.lowercased()
            ownChild = own + "."
        }

        /// The catalogue entry `app` matches, as a `ConflictingApp`; nil for no match and for Overbright itself. The
        /// rules and their order are `ConflictMatcher.match`'s: the first matching entry wins.
        public func match(_ app: RunningApp) -> ConflictingApp? {
            guard let index = entryIndex(of: app) else { return nil }
            let entry = catalog[index]
            return ConflictingApp(entryID: entry.id, severity: entry.severity, bundleID: app.bundleID,
                                  processID: app.processID, displayName: app.localizedName)
        }

        /// Whether a signing team could confirm or veto a match of `bundleID`: it starts with a catalogued prefix
        /// whose entry names teams (a plain string prefix; the team is read only for such bundles).
        public func readsTeam(forBundleID bundleID: String) -> Bool {
            let lowered = bundleID.lowercased()
            return prefixes.contains { $0.namesTeams && lowered.hasPrefix($0.prefix) }
        }

        // MARK: Private

        /// The first entry `app` matches: the smaller of the first exact entry and the first confirmed prefix entry
        /// (an entry matches when either rule holds); executable names only for an app without a bundle ID.
        private func entryIndex(of app: RunningApp) -> Int? {
            guard let bundleID = app.bundleID?.lowercased(), !bundleID.isEmpty else {
                guard let executable = app.executableName?.lowercased(), !executable.isEmpty else { return nil }
                return executables[executable]
            }
            if !own.isEmpty && (bundleID == own || bundleID.hasPrefix(ownChild)) { return nil }
            let byExact = exact[bundleID]
            let limit = byExact ?? catalog.count
            let team = app.teamID?.uppercased()
            let byPrefix = prefixes.first { candidate in
                candidate.entry < limit && ConflictMatcher.hasPrefix(bundleID, candidate.prefix)
                    && confirms(team, entry: candidate.entry)
            }
            guard let byPrefix, !ConflictMatcher.isHelper(bundleID) else { return byExact }
            return byPrefix.entry
        }

        /// A known team confirms a prefix match only when the entry names it; an unread one never vetoes.
        private func confirms(_ team: String?, entry: Int) -> Bool {
            guard let team, !teams[entry].isEmpty else { return true }
            return teams[entry].contains(team)
        }
    }
}
