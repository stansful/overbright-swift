// OverbrightPolicyTests/ConflictMatcherTests.swift — the conflict matcher and the shape of the catalogue.
// ARCHITECTURE.md §7.2, D3: matcher tests use synthetic IDs (com.example…) or reach real entries through
// `ConflictCatalog` by entry ID, so no catalogue identifier is ever written in a test.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct ConflictMatcherTests {
    private let own = "app.overbright.Overbright"
    private let catalog = [
        ConflictCatalogEntry(id: "test-booster", severity: .booster, bundleIDs: ["com.example.Booster"],
                             bundlePrefixes: ["com.example.booster"], teamIDs: ["TEAM123456"]),
        ConflictCatalogEntry(id: "test-colors", severity: .gammaWriter, bundleIDs: ["org.example.Colors"]),
        ConflictCatalogEntry(id: "test-tool", severity: .booster, bundleIDs: [], executableNames: ["example-boost"]),
        ConflictCatalogEntry(id: "test-family", severity: .conditional, bundleIDs: ["net.example.Family.7"],
                             bundlePrefixes: ["net.example.Family"]),
        ConflictCatalogEntry(id: "test-shade", severity: .benign, bundleIDs: ["jp.example.Shade"]),
    ]

    private func app(_ bundleID: String?, executable: String? = nil, team: String? = nil,
                     pid: Int32 = 501, name: String = "Some App") -> ConflictMatcher.RunningApp {
        ConflictMatcher.RunningApp(bundleID: bundleID, executableName: executable, teamID: team, processID: pid,
                                   localizedName: name)
    }
    private func entry(_ running: ConflictMatcher.RunningApp, in catalog: [ConflictCatalogEntry]? = nil) -> String? {
        ConflictMatcher.match(running, in: catalog ?? self.catalog, ownBundleID: own)?.entryID
    }

    @Test func exactAndCaseInsensitive() throws {
        let match = try #require(ConflictMatcher.match(app("org.example.Colors", pid: 77, name: "Цвета"), in: catalog,
                                                       ownBundleID: own))
        #expect(match == ConflictingApp(entryID: "test-colors", severity: .gammaWriter, bundleID: "org.example.Colors",
                                        processID: 77, displayName: "Цвета"))
        #expect(entry(app("ORG.EXAMPLE.COLORS")) == "test-colors")
        #expect(entry(app("org.example.colors")) == "test-colors")
        #expect(entry(app("jp.example.Shade")) == "test-shade")
        #expect(entry(app("org.example.Colors2")) == nil && entry(app("org.example")) == nil)
    }

    @Test func setappTwins() {
        #expect(entry(app("org.example.Colors-setapp")) == "test-colors")
        #expect(entry(app("ORG.example.colors-SETAPP")) == "test-colors")
        #expect(entry(app("org.example.Colors-setapp2")) == nil)
        #expect(entry(app("jp.example.Shade-setapp")) == "test-shade")
    }

    @Test func vendorPrefixes() {
        #expect(entry(app("com.example.booster-MacAppStore")) == "test-booster")
        #expect(entry(app("com.example.Booster.Pro")) == "test-booster")
        #expect(entry(app("com.example.booster_beta")) == "test-booster")
        #expect(entry(app("net.example.Family.8")) == "test-family")             // another major version
        #expect(entry(app("net.example.family")) == "test-family")
    }

    /// No false positive on a sibling app of the same vendor whose ID merely starts with the prefix's letters.
    @Test func noFalsePositiveOnASiblingApp() {
        #expect(entry(app("com.example.boosterx")) == nil)
        #expect(entry(app("com.example.boost")) == nil)
        #expect(entry(app("com.example.Notes")) == nil)
        #expect(entry(app("net.example.FamilyTree")) == nil)
    }

    @Test func executablesOfBundleLessTools() {
        #expect(entry(app(nil, executable: "example-boost")) == "test-tool")
        #expect(entry(app(nil, executable: "EXAMPLE-BOOST")) == "test-tool")
        #expect(entry(app(nil, executable: "example-boost2")) == nil)
        #expect(entry(app(nil)) == nil && entry(app("", executable: nil)) == nil)
        // An executable name never matches an app that has a bundle.
        #expect(entry(app("com.example.Other", executable: "example-boost")) == nil)
    }

    /// The team ID confirms a prefix match: a known, different team vetoes it; an unread one does not.
    @Test func teamConfirmation() {
        #expect(entry(app("com.example.booster-pro", team: "TEAM123456")) == "test-booster")
        #expect(entry(app("com.example.booster-pro", team: "team123456")) == "test-booster")
        #expect(entry(app("com.example.booster-pro", team: "OTHERTEAM1")) == nil)
        #expect(entry(app("com.example.booster-pro", team: nil)) == "test-booster")
        // An exact ID needs no confirmation; a prefix entry without team IDs accepts any team.
        #expect(entry(app("com.example.Booster", team: "OTHERTEAM1")) == "test-booster")
        #expect(entry(app("net.example.Family.9", team: "ANYTEAM123")) == "test-family")
    }

    @Test func ourOwnBundleIDHelpersAndExtensionsAreIgnored() {
        let greedy = [ConflictCatalogEntry(id: "greedy", severity: .booster, bundleIDs: [own],
                                           bundlePrefixes: ["app.overbright"])]
        #expect(entry(app(own), in: greedy) == nil)
        #expect(entry(app("APP.OVERBRIGHT.OVERBRIGHT"), in: greedy) == nil)
        #expect(entry(app("app.overbright.Overbright.Controls"), in: greedy) == nil)
        #expect(entry(app("app.overbright.OverbrightBeta"), in: greedy) == "greedy")     // not ours: another ID
    }

    /// Helpers and extensions of a catalogued app never touch displays: ignored on prefix matches.
    @Test func helpersAreIgnored() {
        for helper in ["com.example.booster.LaunchAtLoginHelper", "com.example.booster.Widgets",
                       "com.example.Booster.LoginItem", "com.example.booster.Launcher", "com.example.booster-agent",
                       "com.example.booster.ShareExtension", "com.example.booster.UpdaterXPC",
                       "org.example.Colors.Helper"] {
            #expect(entry(app(helper)) == nil, "\(helper)")
        }
        // An exact catalogue ID always matches, whatever its words.
        let exact = [ConflictCatalogEntry(id: "daemon", severity: .benign, bundleIDs: ["fr.example.tool.helper"])]
        #expect(entry(app("fr.example.tool.helper"), in: exact) == "daemon")
    }

    /// The first matching entry wins: a catalogue lists S1 first.
    @Test func theFirstEntryWins() {
        let overlapping = [
            ConflictCatalogEntry(id: "first", severity: .booster, bundleIDs: ["com.example.Both"]),
            ConflictCatalogEntry(id: "second", severity: .conditional, bundleIDs: ["com.example.Both"]),
        ]
        #expect(entry(app("com.example.Both"), in: overlapping) == "first")
        #expect(entry(app("com.example.Both"), in: []) == nil)
    }

    // MARK: The catalogue

    /// §7.2: 12 S1, 4 S2, 4 S3 and 3 S4 entries, most severe first, unique stable IDs, identifiers only.
    @Test func catalogueShape() throws {
        let entries = ConflictCatalog.entries
        let counts = Dictionary(grouping: entries, by: \.severity).mapValues(\.count)
        #expect(counts == [.booster: 12, .gammaWriter: 4, .conditional: 4, .benign: 3])
        let order: [ConflictSeverity] = [.booster, .gammaWriter, .conditional, .benign]
        let ranks = entries.map { entry in order.firstIndex(of: entry.severity) ?? 0 }
        #expect(ranks == ranks.sorted())
        #expect(Set(entries.map(\.id)).count == entries.count)
        let bundleShaped = try NSRegularExpression(pattern: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$")
        let identifierShaped = try NSRegularExpression(pattern: "^[A-Za-z0-9._-]+$")
        func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
            regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        for entry in entries {
            #expect(!(entry.bundleIDs + entry.executableNames).isEmpty, "\(entry.id) identifies nothing")
            #expect(matches(identifierShaped, entry.id), "\(entry.id)")
            for id in entry.bundleIDs + entry.bundlePrefixes { #expect(matches(bundleShaped, id), "\(entry.id): \(id)") }
            for name in entry.executableNames { #expect(matches(identifierShaped, name), "\(entry.id): \(name)") }
            for team in entry.teamIDs { #expect(team.count == 10 && team == team.uppercased(), "\(entry.id)") }
            // Every prefix covers at least one of the entry's own IDs, so a typo cannot hide.
            for prefix in entry.bundlePrefixes {
                #expect(entry.bundleIDs.contains { $0.lowercased().hasPrefix(prefix.lowercased()) }, "\(entry.id)")
            }
        }
        #expect(ConflictCatalog.entry(id: "booster-01")?.severity == .booster)
        #expect(ConflictCatalog.entry(id: "missing") == nil)
    }

    /// Every real entry matches its own identifiers and their Setapp twins, with the entry's own severity, and
    /// Overbright never matches itself.
    @Test func everyCatalogueEntryMatchesItsOwnIdentifiers() throws {
        for entry in ConflictCatalog.entries {
            for bundleID in entry.bundleIDs {
                for variant in [bundleID, bundleID.uppercased(), bundleID + ConflictMatcher.setappSuffix] {
                    let match = ConflictMatcher.match(app(variant, team: entry.teamIDs.first), in: ConflictCatalog.entries,
                                                      ownBundleID: own)
                    #expect(match?.entryID == entry.id && match?.severity == entry.severity, "\(entry.id)")
                }
            }
            for executable in entry.executableNames {
                #expect(self.entry(app(nil, executable: executable), in: ConflictCatalog.entries) == entry.id)
            }
        }
        #expect(self.entry(app(own), in: ConflictCatalog.entries) == nil)
        #expect(self.entry(app("com.apple.Safari"), in: ConflictCatalog.entries) == nil)
        // The prefix family of the first booster: a build with an unlisted suffix still matches, a sibling app of the
        // same vendor does not, and a different team vetoes the prefix.
        let first = try #require(ConflictCatalog.entry(id: "booster-01"))
        let prefix = try #require(first.bundlePrefixes.first)
        #expect(self.entry(app(prefix + "-Beta"), in: ConflictCatalog.entries) == "booster-01")
        #expect(self.entry(app(prefix + "Sibling"), in: ConflictCatalog.entries) == nil)
        #expect(self.entry(app(prefix + "-Beta", team: "ZZZZZZZZZZ"), in: ConflictCatalog.entries) == nil)
    }
}
