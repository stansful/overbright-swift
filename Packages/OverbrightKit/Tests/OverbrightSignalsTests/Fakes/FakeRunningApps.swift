// OverbrightSignalsTests/Fakes/FakeRunningApps.swift — a scripted `RunningAppsSource` and a synthetic catalogue with a
// test matcher. D3: tests never contain real catalogue bundle IDs; the matcher here is the test's own (Policy's real
// `ConflictMatcher` is WP1's and has its own suite), so these suites test the probe's plumbing.
import Foundation
import OverbrightCore
import OverbrightPolicy
@testable import OverbrightSignals

@MainActor final class FakeRunningApps: RunningAppsSource {
    var apps: [RunningAppInfo] = []
    var teams: [URL: String] = [:]
    var processes: [ProcessScanner.Process] = []
    private(set) var teamReads: [URL] = []
    private(set) var scans = 0
    /// Reads of the running list (one per full pass).
    private(set) var listReads = 0

    func runningApplications() -> [RunningAppInfo] { listReads += 1; return apps }
    func teamID(ofBundleAt url: URL) -> String? { teamReads.append(url); return teams[url] }
    func scanProcesses() async -> [ProcessScanner.Process] { scans += 1; return processes }
}

/// Synthetic catalogue entries (never real products).
enum TestCatalog {
    static let booster = ConflictCatalogEntry(id: "test-booster", severity: .booster, bundleIDs: ["com.example.Booster"])
    static let tint = ConflictCatalogEntry(id: "test-tint", severity: .gammaWriter, bundleIDs: ["com.example.tint"])
    static let dimmer = ConflictCatalogEntry(id: "test-dimmer", severity: .conditional, bundleIDs: [],
                                             bundlePrefixes: ["com.example.dimmer"], teamIDs: ["TEAM123456"])
    static let shade = ConflictCatalogEntry(id: "test-shade", severity: .benign, bundleIDs: ["com.example.shade"])
    static let tool = ConflictCatalogEntry(id: "test-tool", severity: .booster, bundleIDs: [], executableNames: ["example-boost"])
    static let all = [booster, tint, dimmer, shade, tool]

    /// The matcher rules of §7.2 in their simplest form, for plumbing tests.
    static func match(_ app: ConflictMatcher.RunningApp, in catalog: [ConflictCatalogEntry],
                      ownBundleID: String) -> ConflictingApp? {
        let bundle = app.bundleID?.lowercased()
        if bundle == ownBundleID.lowercased() { return nil }
        for entry in catalog {
            let exact = bundle.map { id in entry.bundleIDs.contains { $0.lowercased() == id } } ?? false
            let prefix = bundle.map { id in
                entry.bundlePrefixes.contains { id.hasPrefix($0.lowercased()) }
                    && (entry.teamIDs.isEmpty || app.teamID.map(entry.teamIDs.contains) == true)
            } ?? false
            let executable = app.executableName.map(entry.executableNames.contains) ?? false
            if exact || prefix || executable {
                return ConflictingApp(entryID: entry.id, severity: entry.severity, bundleID: app.bundleID,
                                      processID: app.processID, displayName: app.localizedName)
            }
        }
        return nil
    }
}

/// A matcher that records which processes it was asked about, then answers as `TestCatalog.match`.
@MainActor final class CountingMatcher {
    private(set) var asked: [Int32] = []

    func match(_ app: ConflictMatcher.RunningApp, in catalog: [ConflictCatalogEntry], ownBundleID: String) -> ConflictingApp? {
        asked.append(app.processID)
        return TestCatalog.match(app, in: catalog, ownBundleID: ownBundleID)
    }
}
