// OverbrightDesignTests/SymbolTests.swift — DESIGN.md §13.1: one allow-list of SF Symbols, each available on macOS 14,
// none restricted, no FaceTime `video*` glyphs, and the moon only for Focus. Ported from Cranny's SymbolTests (the
// owner's MIT code). ARCHITECTURE.md §10.11 Acceptance.
import AppKit
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite struct SymbolTests {
    nonisolated private static let glyphs = URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources")
    nonisolated private static let hasCatalogue = FileManager.default.fileExists(
        atPath: glyphs.appending(path: "name_availability.plist").path)
    nonisolated private static let names = Set(OverbrightSymbol.allCases.map(\.rawValue))
    /// The repository root (this file is Packages/OverbrightKit/Tests/OverbrightDesignTests/SymbolTests.swift).
    nonisolated static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func plist(_ name: String) throws -> [String: Any] {
        let data = try Data(contentsOf: glyphs.appending(path: name))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @MainActor @Test func everySymbolResolves() {
        let missing = Self.names.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
        #expect(missing.isEmpty, "\(missing.sorted())")
    }

    /// The system's own catalogue: the release that introduced each name, and the restricted names.
    @Test(.enabled(if: hasCatalogue)) func everySymbolExistsOnMacOS14AndNoneIsRestricted() throws {
        let availability = try Self.plist("name_availability.plist")
        let introduced = try #require(availability["symbols"] as? [String: String])
        let releases = try #require(availability["year_to_release"] as? [String: [String: String]])
        for name in Self.names.sorted() {
            let year = try #require(introduced[name], "\(name) is not an SF Symbol")
            let macOS = try #require(releases[year]?["macOS"], "\(name): no macOS release for \(year)")
            #expect(macOS.compare("14.0", options: .numeric) != .orderedDescending, "\(name) needs macOS \(macOS)")
        }
        let restricted = Set(try Self.plist("symbol_restrictions.strings").keys)
        #expect(restricted.count > 100, "the restrictions list was read")
        #expect(Self.names.intersection(restricted).isEmpty, "\(Self.names.intersection(restricted).sorted())")
    }

    /// `OverbrightSymbol` and the table of DESIGN.md §13.1 list the same names.
    @Test func listMatchesTheDesignTable() throws {
        let text = try String(contentsOf: Self.repository.appending(path: "docs/DESIGN.md"), encoding: .utf8)
        let section = try #require(text.components(separatedBy: "### 13.1 SF Symbols").dropFirst().first)
        let table = try #require(section.components(separatedBy: "Never use `video*`").first)
        var names = Set<String>()
        for line in table.components(separatedBy: "\n") where line.hasPrefix("| ") && !line.hasPrefix("| Role") {
            let cells = line.components(separatedBy: "|")
            guard cells.count > 2 else { continue }
            for token in cells[2].components(separatedBy: "`").enumerated()
            where token.offset % 2 == 1 && token.element.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "." }) {
                names.insert(token.element)
            }
        }
        #expect(names.count > 40)
        #expect(names.subtracting(Self.names).isEmpty, "in §13.1, not in OverbrightSymbol: \(names.subtracting(Self.names).sorted())")
        #expect(Self.names.subtracting(names).isEmpty, "in OverbrightSymbol, not in §13.1: \(Self.names.subtracting(names).sorted())")
    }

    /// FaceTime's `video*` glyphs are never used (DESIGN.md §13.1).
    @Test func noVideoGlyphs() {
        #expect(Self.names.filter { $0.hasPrefix("video") }.isEmpty)
    }

    /// The moon reads as macOS's Focus and Sleep: it is used only where the copy is about Focus, never for dimming.
    @Test func theMoonIsOnlyForFocus() throws {
        let sources = Self.repository.appending(path: "Packages/OverbrightKit/Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var uses: [(file: String, context: String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            for (i, line) in lines.enumerated() where line.contains(".moonFill") || line.contains("\"moon") {
                if url.lastPathComponent == "OverbrightSymbol.swift" { continue }        // the allow-list itself
                let context = lines[max(0, i - 2)...i].joined(separator: "\n")
                uses.append((url.lastPathComponent, context))
            }
        }
        #expect(!uses.isEmpty, "the Focus banner uses the moon")
        for use in uses {
            #expect(use.context.localizedCaseInsensitiveContains("focus"), "the moon outside Focus in \(use.file): \(use.context)")
        }
    }

    /// Every chip, banner and HUD glyph is on the list (they are `OverbrightSymbol`s by type) and the dim glyphs are
    /// suns, never the moon (DESIGN.md §0 #13).
    @Test func dimmingUsesTheSmallSun() {
        #expect(OverbrightSymbol.sunMin.rawValue == "sun.min")
        let hud = HUDText.make(LevelChange(sequence: 1, kind: .automationStopped(.focusOff), source: .automation,
                                           display: nil), status: .initial, on: nil, in: english)
        #expect(hud?.symbol != .moonFill)
    }
}
