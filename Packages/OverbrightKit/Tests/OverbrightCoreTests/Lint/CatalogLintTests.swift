// OverbrightCoreTests/Lint/CatalogLintTests.swift — the String Catalog scans of ARCHITECTURE.md §9.1 "Lint tests
// (Core)" and DESIGN.md §16: key caps are never literal copy, and a button that goes somewhere in Overbright names the
// action, never a settings place. Every catalog: the package's `Sources/*/Resources/*.xcstrings`, `App/*.xcstrings`
// and `Controls/*.xcstrings`.
import Foundation
import Testing

@Suite struct CatalogLintTests {
    /// DESIGN.md §16: copy that mentions a shortcut takes the live binding as a placeholder; "⌃⌥⌘B" typed into a key or
    /// a translation is wrong on every other keyboard layout.
    @Test func noLiteralKeyCapsInCatalogs() throws {
        let keyCaps = try NSRegularExpression(pattern: "[⌃⌥⇧⌘]+[^\\s%⌃⌥⇧⌘]")
        #expect(!SourceScan.matches(keyCaps, in: "Press ⌃⌥⌘B to turn it on.").isEmpty)
        #expect(SourceScan.matches(keyCaps, in: "Press %@ to turn it on.").isEmpty)
        let catalogs = SourceScan.catalogs()
        var hits: [String] = []
        for (path, strings) in catalogs {
            for (key, entry) in strings {
                let texts = [key] + SourceScan.values(of: entry as? [String: Any] ?? [:]).map(\.text)
                if texts.contains(where: { !SourceScan.matches(keyCaps, in: $0).isEmpty }) { hits.append("\(path): \(key)") }
            }
        }
        #expect(catalogs.count >= 17)
        #expect(hits.isEmpty, "literal key caps in copy (use the live binding): \(hits)")
    }

    /// DESIGN.md §16: "Open System Settings" goes to System Settings; a button into Overbright names the action
    /// ("Choose Peak…", "Settings for This Display…"), never "‹X› Settings…".
    @Test func noSettingsDestinationLabels() throws {
        let destination = try NSRegularExpression(pattern: "\\p{L}+\\s+[Ss]ettings…")
        #expect(!SourceScan.matches(destination, in: "Menu Bar Settings…").isEmpty)
        #expect(SourceScan.matches(destination, in: "Settings for This Display…").isEmpty)
        #expect(SourceScan.matches(destination, in: "Settings…").isEmpty)
        #expect(SourceScan.matches(destination, in: "Open System Settings").isEmpty)
        var hits: [String] = []
        for (path, strings) in SourceScan.catalogs() {
            for (key, entry) in strings {
                let english = SourceScan.values(of: entry as? [String: Any] ?? [:]).filter { $0.language == "en" }.map(\.text)
                if ([key] + english).contains(where: { !SourceScan.matches(destination, in: $0).isEmpty }) {
                    hits.append("\(path): \(key)")
                }
            }
        }
        #expect(hits.isEmpty, "name the action, not a settings place: \(hits)")
    }
}
