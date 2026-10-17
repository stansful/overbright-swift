// OverbrightPolicyTests/ConflictMatcherPreparedTests.swift — the prepared matcher answers exactly as the as-built one.
// ARCHITECTURE.md §7.2, §9.1 (property tests with TestSupport's seeded generator), D3: synthetic IDs only; the real
// catalogue is reached through `ConflictCatalog.entries`, and its corpus is derived from the entries, never written.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct ConflictMatcherPreparedTests {
    /// A synthetic catalogue built to make order matter: a broad prefix before a later exact ID, a team-confirmed prefix
    /// before an exact ID of another entry, duplicates across entries, an exact helper ID, our own ID listed.
    private static let synthetic = [
        ConflictCatalogEntry(id: "s-booster", severity: .booster, bundleIDs: ["com.example.Booster", "com.example.booster-Store"],
                             bundlePrefixes: ["com.example.booster"], teamIDs: ["TEAM123456", "team654321"]),
        ConflictCatalogEntry(id: "s-tool", severity: .booster, bundleIDs: [], executableNames: ["example-boost", "Example-Tool"]),
        ConflictCatalogEntry(id: "s-colors", severity: .gammaWriter, bundleIDs: ["org.example.Colors"],
                             bundlePrefixes: ["org.example"]),
        ConflictCatalogEntry(id: "s-family", severity: .conditional, bundleIDs: ["net.example.Family.7", "com.example.booster.Pro"],
                             bundlePrefixes: ["net.example.Family"], teamIDs: ["FAMILYTEAM"]),
        ConflictCatalogEntry(id: "s-dup", severity: .conditional, bundleIDs: ["org.example.Colors", "org.example.Paint"],
                             executableNames: ["EXAMPLE-BOOST", "dup-tool"]),
        ConflictCatalogEntry(id: "s-shade", severity: .benign, bundleIDs: ["jp.example.Shade", "jp.example.shade.helper"],
                             bundlePrefixes: ["jp.example.shade_"]),
        ConflictCatalogEntry(id: "s-greedy", severity: .benign, bundleIDs: ["app.example.Own"], bundlePrefixes: ["app.example"]),
    ]
    private static let owns = ["app.example.Own", "APP.EXAMPLE.OWN", "", "app.overbright.Overbright"]

    private func app(_ bundleID: String?, executable: String? = nil, team: String? = nil, pid: Int32 = 501)
        -> ConflictMatcher.RunningApp {
        ConflictMatcher.RunningApp(bundleID: bundleID, executableName: executable, teamID: team, processID: pid,
                                   localizedName: "App \(pid)")
    }

    // MARK: The property

    /// Over a seeded corpus (exact IDs, case variants, `-setapp` twins, prefixes at `.`, `-` and `_`, siblings,
    /// helpers, executables, team IDs, our own ID and its helpers), every app gets the as-built answer, whole.
    @Test(arguments: [0, 1, 2, 3]) func preparedEqualsAsBuiltOnTheSyntheticCatalogue(ownIndex: Int) {
        let own = Self.owns[ownIndex]
        let stats = compare(catalog: Self.synthetic, own: own, count: 3000, seed: UInt64(0x5E1 + ownIndex))
        #expect(stats.mismatches.isEmpty, "\(stats.mismatches.prefix(5))")
        // Not vacuous: hits of every kind, misses, and team vetoes.
        #expect(stats.hits > 600 && stats.misses > 600, "\(stats)")
        #expect(stats.entriesHit.count == Self.synthetic.count, "\(stats.entriesHit.sorted())")
        #expect(stats.teamReads > 100 && stats.vetoes > 20, "\(stats)")
    }

    /// The real catalogue (most severe first, prefixes with a team) over a corpus derived from its own identifiers.
    @Test func preparedEqualsAsBuiltOnTheRealCatalogue() {
        let stats = compare(catalog: ConflictCatalog.entries, own: "app.overbright.Overbright", count: 1500, seed: 0xCA7)
        #expect(stats.mismatches.isEmpty, "\(stats.mismatches.prefix(5))")
        #expect(stats.hits > 300 && stats.misses > 300, "\(stats)")
        #expect(stats.entriesHit.count == ConflictCatalog.entries.count, "\(stats.entriesHit.sorted())")
    }

    // MARK: Cases the property must cover

    /// The first matching entry wins whichever rule matched it: an earlier prefix beats a later exact ID, and an earlier
    /// prefix vetoed by its team falls through to the later exact ID.
    @Test func theFirstMatchingEntryWinsAcrossRules() {
        let prepared = ConflictMatcher.Prepared(catalog: Self.synthetic, ownBundleID: "app.example.Own")
        #expect(prepared.match(app("com.example.booster.Pro"))?.entryID == "s-booster")
        #expect(prepared.match(app("com.example.booster.Pro", team: "OTHERTEAM1"))?.entryID == "s-family")
        #expect(prepared.match(app("org.example.Paint"))?.entryID == "s-colors")          // the broad prefix comes first
        #expect(prepared.match(app("org.example.Colors"))?.entryID == "s-colors")         // the duplicate's first entry
        #expect(prepared.match(app(nil, executable: "example-BOOST"))?.entryID == "s-tool")
        #expect(prepared.match(app("jp.example.shade.helper"))?.entryID == "s-shade")     // an exact helper ID matches
        #expect(prepared.match(app("jp.example.shade_beta.helper")) == nil)              // a prefix helper does not
        #expect(prepared.match(app("app.example.Own.Widget")) == nil)                     // ours
        #expect(prepared.match(app("app.example.Other"))?.entryID == "s-greedy")
        #expect(prepared.match(app("", executable: "dup-tool"))?.entryID == "s-dup")      // an empty ID has no bundle
        #expect(prepared.match(app(nil)) == nil)
    }

    /// A team is read only for a bundle that starts with a catalogued prefix whose entry names teams (the probe's
    /// as-built question: a plain string prefix).
    @Test func readsTeamOnlyForPrefixesThatNameTeams() {
        let prepared = ConflictMatcher.Prepared(catalog: Self.synthetic, ownBundleID: "app.example.Own")
        #expect(prepared.readsTeam(forBundleID: "COM.EXAMPLE.BOOSTER.pro"))
        #expect(prepared.readsTeam(forBundleID: "com.example.boosterx"))                   // no boundary needed
        #expect(prepared.readsTeam(forBundleID: "net.example.Family.8"))
        #expect(!prepared.readsTeam(forBundleID: "org.example.Colors.2"))                  // a prefix without teams
        #expect(!prepared.readsTeam(forBundleID: "com.example.boost"))
    }

    // MARK: Corpus

    private struct Stats: CustomStringConvertible {
        var hits = 0, misses = 0, teamReads = 0, vetoes = 0
        var entriesHit: Set<String> = []
        var mismatches: [String] = []
        var description: String {
            "hits \(hits), misses \(misses), team reads \(teamReads), vetoes \(vetoes), entries \(entriesHit.count)"
        }
    }

    private func compare(catalog: [ConflictCatalogEntry], own: String, count: Int, seed: UInt64) -> Stats {
        var random = SeededGenerator(seed: seed)
        let prepared = ConflictMatcher.Prepared(catalog: catalog, ownBundleID: own)
        var stats = Stats()
        for index in 0..<count {
            let candidate = generate(catalog: catalog, own: own, pid: Int32(index), using: &random)
            let expected = ConflictMatcher.match(candidate, in: catalog, ownBundleID: own)
            let actual = prepared.match(candidate)
            if expected != actual {
                stats.mismatches.append("\(candidate): \(String(describing: expected)) ≠ \(String(describing: actual))")
            }
            if let expected { stats.hits += 1; stats.entriesHit.insert(expected.entryID) } else { stats.misses += 1 }
            if candidate.teamID != nil, expected?.entryID != ConflictMatcher.match(
                ConflictMatcher.RunningApp(bundleID: candidate.bundleID, executableName: candidate.executableName, teamID: nil,
                                           processID: candidate.processID, localizedName: candidate.localizedName),
                in: catalog, ownBundleID: own)?.entryID {
                stats.vetoes += 1                                    // the team changed the answer
            }
            if let bundleID = candidate.bundleID {
                let asBuilt = catalog.contains { entry in
                    !entry.teamIDs.isEmpty && entry.bundlePrefixes.contains { bundleID.lowercased().hasPrefix($0.lowercased()) }
                }
                if asBuilt != prepared.readsTeam(forBundleID: bundleID) { stats.mismatches.append("team read: \(bundleID)") }
                if asBuilt { stats.teamReads += 1 }
            }
        }
        return stats
    }

    /// One running app: a bundle ID shaped from the catalogue, our own ID or noise, or a bundle-less executable.
    private func generate(catalog: [ConflictCatalogEntry], own: String, pid: Int32,
                          using random: inout SeededGenerator) -> ConflictMatcher.RunningApp {
        let exact = catalog.flatMap(\.bundleIDs), prefixes = catalog.flatMap(\.bundlePrefixes)
        let executables = catalog.flatMap(\.executableNames), teams = catalog.flatMap(\.teamIDs)
        let noise = ["com.example.Notes", "org.example", "net.example", "com.example.boost", "x.y"]
        let ownIDs = own.isEmpty ? [] : [own]
        let roll = Int.random(in: 0..<100, using: &random)
        let team = pick([nil, nil, ""] + teams.map(Optional.some) + ["OTHERTEAM1"], using: &random)
            .flatMap { $0 }.map { vary($0, using: &random) }
        guard roll >= 12 else {                                     // a bundle-less tool (or an empty bundle ID)
            let name = vary(pick(executables + ["example-other", ""], using: &random) ?? "", using: &random)
            let bundle: String? = roll < 3 ? "" : nil
            return app(bundle, executable: roll < 10 ? name : nil, team: team, pid: pid)
        }
        var id = pick(exact + exact + prefixes + prefixes + ownIDs + noise, using: &random) ?? "x.y"
        switch Int.random(in: 0..<12, using: &random) {
        case 0: id += pick(["-setapp", "-SETAPP", "-setapp2", "-setappx"], using: &random) ?? ""
        case 1: id += (pick([".", "-", "_"], using: &random) ?? ".") + (pick(["Pro", "beta", "2", "MacAppStore"], using: &random) ?? "")
        case 2: id += pick(["x", "2", "Sibling", "Tree"], using: &random) ?? ""
        case 3: id += pick([".helper", ".LaunchAtLoginHelper", "-agent", ".Widgets", ".ShareExtension", "XPC",
                            ".LoginItem", ".launcher"], using: &random) ?? ""
        case 4: id = String(id.dropLast())
        case 5: id = (pick(prefixes + ownIDs + noise, using: &random) ?? id) + "." + (pick(["Helper", "Tool"], using: &random) ?? "")
        default: break
        }
        return app(vary(id, using: &random), executable: pick(executables + ["other"], using: &random), team: team, pid: pid)
    }

    /// `text` as written, lowercased, uppercased, or with each letter's case flipped at random.
    private func vary(_ text: String, using random: inout SeededGenerator) -> String {
        switch Int.random(in: 0..<4, using: &random) {
        case 0: return text.lowercased()
        case 1: return text.uppercased()
        case 2: return text.map { Bool.random(using: &random) ? $0.uppercased() : $0.lowercased() }.joined()
        default: return text
        }
    }

    private func pick<T>(_ items: [T], using random: inout SeededGenerator) -> T? {
        items.isEmpty ? nil : items[Int.random(in: 0..<items.count, using: &random)]
    }
}
