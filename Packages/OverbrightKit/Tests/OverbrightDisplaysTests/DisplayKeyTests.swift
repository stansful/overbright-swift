// OverbrightDisplaysTests/DisplayKeyTests.swift — displays are keyed by their CoreGraphics UUID, never by name
// (ARCHITECTURE.md §3.2, §3.6, D8): keys normalise case, the directory lists the built-in display first and then sorts
// by key whatever order CoreGraphics reports, and Russian names give identical keys, order and classes. The real
// `DisplayKey.of` is exercised read-only in `RealDisplayReadTests`.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct DisplayKeyTests {
    @Test func keysNormaliseCase() {
        let lower = DisplayKey(rawValue: "0b21e7f1-0000-4000-8000-000000000002")
        #expect(lower == DisplayFixture.Keys.mpg322ux)
        #expect(lower.description == "0B21E7F1-0000-4000-8000-000000000002")
        #expect(Set([lower, DisplayFixture.Keys.mpg322ux]).count == 1)
    }

    @Test func builtInFirstThenByKey() {
        var other = RawDisplayFixtures.msi()
        other.id = 9
        other.key = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000000")    // sorts before the built-in's key
        let registry = RawDisplayFixtures.ownerRegistry()
        let orders = [[RawDisplayFixtures.msi(), other, RawDisplayFixtures.builtIn()],
                      [other, RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi()],
                      [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(), other]]
        for raw in orders {
            let keys = DisplayFactsBuilder.facts(from: raw, registry: registry).map(\.ref.key)
            #expect(keys == [DisplayFixture.Keys.builtIn, other.key, DisplayFixture.Keys.mpg322ux])
        }
    }

    @Test func russianNamesChangeNothingButTheName() {
        let registry = RawDisplayFixtures.ownerRegistry()
        let english = DisplayFactsBuilder.facts(from: [RawDisplayFixtures.msi(), RawDisplayFixtures.builtIn()],
                                                registry: registry)
        let russian = DisplayFactsBuilder.facts(
            from: [RawDisplayFixtures.msi(name: "MPG322UX OLED"),
                   RawDisplayFixtures.builtIn(name: "Встроенный дисплей Retina")],
            registry: registry)
        #expect(russian.map(\.ref) == english.map(\.ref))
        #expect(russian.map(\.panelClass) == english.map(\.panelClass))
        #expect(russian.map(\.isMirrored) == english.map(\.isMirrored))
        var renamed = english
        renamed[0].name = "Встроенный дисплей Retina"
        #expect(russian == renamed)
        // Core's Russian fixture lists the same keys as the English ones.
        #expect(DisplayFixture.russianNames.displays.map(\.key) == [DisplayFixture.Keys.builtIn, DisplayFixture.Keys.mpg322ux])
    }

    @Test func perDisplaySettingsAreAnObjectKeyedByUUID() throws {
        let preferences: [DisplayKey: DisplayPreferences] = [DisplayFixture.Keys.mpg322ux: DisplayPreferences(boostEnabled: true)]
        let data = try JSONEncoder().encode(preferences)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Array(object.keys) == ["0B21E7F1-0000-4000-8000-000000000002"])
        // A key written in lower case by another source reads back as the same display.
        let text = try #require(String(data: data, encoding: .utf8))
        let lowered = text.replacingOccurrences(of: "0B21E7F1", with: "0b21e7f1")
        let decoded = try JSONDecoder().decode([DisplayKey: DisplayPreferences].self, from: Data(lowered.utf8))
        #expect(decoded == preferences)
    }
}
