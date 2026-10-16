// OverbrightSignals/Conflicts/RunningAppsConflictProbe.swift — the real `ConflictProbe`. ARCHITECTURE.md §3.6, §7.2,
// §7.4 (the launch rescue asks it before touching any table), §10.8.
// Matching is Policy's pure `ConflictMatcher` over the catalogue (exact bundle ID and its `-setapp` twin, vendor
// prefixes, executable names, optional team ID); this probe only feeds it: the running applications (read live on every
// call, ≈ 0.04 ms, so the launch check before `SignalsMonitor.start()` already sees them), the signing team for bundles
// whose ID starts with a catalogued prefix that names teams (read once per bundle and process), and, for an unexplained drift, the
// libproc scan off the main actor. Names are never matched; `displayName` is `localizedName`, for the UI only.
// Thread: main (the scan inside `attributeDrift()` runs off the main actor).
import Foundation
import OverbrightCore
import OverbrightPolicy

/// Finds running apps that also change display colours or brightness.
public final class RunningAppsConflictProbe: ConflictProbe {
    /// Policy's matcher signature (injected so tests feed synthetic catalogues before the real catalogue exists).
    typealias Matcher = (ConflictMatcher.RunningApp, [ConflictCatalogEntry], String) -> ConflictingApp?

    private let catalog: [ConflictCatalogEntry]
    private let ownBundleID: String
    private let source: any RunningAppsSource
    private let match: Matcher
    /// Signing teams by bundle and process (a relaunch after an update reads again).
    private var teams: [TeamKey: String?] = [:]

    /// The live probe over `catalog` (Policy's conflict catalogue); `ownBundleID` is ignored by the matcher.
    /// Constructing it touches nothing.
    public convenience init(catalog: [ConflictCatalogEntry], ownBundleID: String = Log.subsystem) {
        self.init(catalog: catalog, ownBundleID: ownBundleID, source: WorkspaceRunningApps(), match: ConflictMatcher.match)
    }

    /// A probe over `source` with `match` (tests).
    init(catalog: [ConflictCatalogEntry], ownBundleID: String, source: any RunningAppsSource,
         match: @escaping Matcher) {
        self.catalog = catalog; self.ownBundleID = ownBundleID; self.source = source; self.match = match
    }

    /// The running catalogue matches, most severe first (S1, S2, S3, S4), then by process ID.
    public func runningConflicts() -> [ConflictingApp] {
        conflicts(in: source.runningApplications())
    }

    /// The running matches right after a workspace launch or termination notification: the launched app counts even
    /// if the running list does not show it yet, and the terminated process no longer counts even if it still does.
    func runningConflicts(launched: RunningAppInfo?, terminatedPID: Int32?) -> [ConflictingApp] {
        var apps = source.runningApplications().filter { $0.processID != terminatedPID }
        if let launched, launched.processID != terminatedPID, !apps.contains(where: { $0.processID == launched.processID }) {
            apps.append(launched)
        }
        return conflicts(in: apps)
    }

    /// The matches among `apps`, most severe first.
    func conflicts(in apps: [RunningAppInfo]) -> [ConflictingApp] {
        apps.compactMap(conflict(for:)).sorted { ($0.severity.rank, $0.processID) < ($1.severity.rank, $1.processID) }
    }

    /// The match for one app, if any.
    func conflict(for app: RunningAppInfo) -> ConflictingApp? {
        let running = ConflictMatcher.RunningApp(bundleID: app.bundleID, executableName: app.executableName,
                                                 teamID: teamID(for: app), processID: app.processID,
                                                 localizedName: app.localizedName)
        return match(running, catalog, ownBundleID)
    }

    /// The app behind an unexplained drift: a running S1–S3 app first; otherwise one libproc scan, off the main actor,
    /// for processes LaunchServices does not list; nil when nobody can be named (the UI then uses the generic text).
    public func attributeDrift() async -> ConflictingApp? {
        let apps = source.runningApplications()
        if let named = conflicts(in: apps).first(where: { $0.severity != .benign }) { return named }
        let listed = Set(apps.map(\.processID))
        for process in await source.scanProcesses() where !listed.contains(process.processID) {
            let bundleURL = process.bundlePath.map { URL(fileURLWithPath: $0, isDirectory: true) }
            let app = RunningAppInfo(bundleID: process.bundleID, processID: process.processID,
                                     executableName: process.executableName, bundleURL: bundleURL,
                                     localizedName: process.executableName, isRegular: false)
            guard var hit = conflict(for: app), hit.severity != .benign else { continue }
            if let bundleURL { hit.displayName = await Self.name(of: bundleURL) }
            return hit
        }
        return nil
    }

    // MARK: Private

    /// Finder's name of a bundle found by the scan (read off the main actor; never a bundle identifier).
    @concurrent private nonisolated static func name(of bundle: URL) async -> String { AppIdentity.name(of: bundle) }

    /// The signing team, read only when a catalogued prefix with team IDs could match (cached per bundle).
    private func teamID(for app: RunningAppInfo) -> String? {
        guard let bundleID = app.bundleID?.lowercased(), let url = app.bundleURL,
              catalog.contains(where: { entry in
                  !entry.teamIDs.isEmpty && entry.bundlePrefixes.contains { bundleID.hasPrefix($0.lowercased()) }
              }) else { return nil }
        let key = TeamKey(bundle: url, processID: app.processID)
        if let cached = teams[key] { return cached }
        let team = source.teamID(ofBundleAt: url)
        teams[key] = team
        return team
    }
}

/// One bundle as one process ran it.
private nonisolated struct TeamKey: Hashable {
    var bundle: URL
    var processID: Int32
}

private extension ConflictSeverity {
    /// S1 first.
    nonisolated var rank: Int {
        switch self {
        case .booster: 0
        case .gammaWriter: 1
        case .conditional: 2
        case .benign: 3
        }
    }
}
