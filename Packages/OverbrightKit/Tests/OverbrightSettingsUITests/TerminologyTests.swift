// OverbrightSettingsUITests/TerminologyTests.swift — the words of Settings, calibration and the self-test against
// DESIGN.md §16 (ARCHITECTURE.md §8.8): the vocabulary ("extra brightness", never "boost" or "EDR" in copy; "trigger"
// and "headroom" only in Advanced, the self-test and diagnostics; "Compatibility mode", never "fallback"; "Max" never
// for a ceiling), title case for push buttons and sheet buttons, sentence case for row labels, a "<Surface>: <purpose>"
// comment on every key, and the Russian glossary wherever Russian is translated (pending keys carry English until
// WP15). Reads SettingsUI's catalog and the shell's Calibration table from the source tree.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSettingsUI

/// One key of a catalog, in English and Russian.
private struct Entry {
    let table: String
    let key: String
    let english: String
    let russian: String?
    let comment: String
}

private enum Catalog {
    static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "Sources")
    static let tables = ["OverbrightSettingsUI/Resources/Localizable.xcstrings", "OverbrightAppShell/Resources/Calibration.xcstrings"]

    /// Every entry: the English text is the `en` value when there is one (keys made with `defaultValue:`), else the
    /// key; Russian only when translated (not pending).
    static func entries() throws -> [Entry] {
        try tables.flatMap { table -> [Entry] in
            let data = try Data(contentsOf: sources.appending(path: table))
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try #require(json["strings"] as? [String: [String: Any]])
            return strings.compactMap { key, entry in
                if entry["extractionState"] as? String == "stale" { return nil }
                let localizations = entry["localizations"] as? [String: Any] ?? [:]
                func unit(_ language: String) -> [String: Any]? {
                    (localizations[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                }
                let english = unit("en")?["value"] as? String ?? key
                let ru = unit("ru")
                let russian = ru?["state"] as? String == "translated" ? ru?["value"] as? String : nil
                return Entry(table: table, key: key, english: english, russian: russian,
                             comment: entry["comment"] as? String ?? "")
            }
        }
    }

    /// The surfaces this package words.
    static func isOurs(_ entry: Entry) -> Bool {
        ["Settings ▸ General", "Settings ▸ Displays", "Settings ▸ Automations", "Settings ▸ Shortcuts", "Settings ▸ Fill Light",
         "Settings ▸ Advanced", "Calibration:", "Self-test:"].contains { entry.comment.hasPrefix($0) }
    }

    /// The text without placeholders.
    static func words(_ text: String) -> String { text.replacing(/%(\d+\$)?[@dlf]+/, with: "") }
}

@MainActor @Suite struct TerminologyTests {
    @Test func everyKeyHasASurfaceComment() throws {
        let entries = try Catalog.entries()
        #expect(entries.count > 200)
        let missing = entries.filter { !$0.comment.contains(": ") || $0.comment.contains("\n") }.map(\.key)
        #expect(missing.isEmpty, "keys without one “<Surface>: <purpose>” comment: \(missing)")
    }

    /// DESIGN.md §16's vocabulary.
    @Test func theVocabularyIsDesigns() throws {
        let banned: [(Regex<Substring>, String)] = [
            (/(?i)\bboost/, "“extra brightness”, never “boost”"), (/(?i)\b(?:HDR|XDR) mode\b/, "no “HDR mode”"),
            (/\bEDR\b/, "no “EDR” in copy"), (/(?i)\bgamma\b/, "no “gamma”"), (/(?i)\bfallback\b/, "“Compatibility mode”"),
            (/(?i)\bring light\b/, "“Fill Light”"), (/(?i)\bpanic\b/, "“Back to Standard”"),
            (/(?i)\breset brightness\b/, "“Back to Standard”"), (/(?i)\bnight mode\b/, "“Dim below minimum”"),
            (/(?i)\bdimmer\b/, "“Less Bright”"), (/(?i)\bmonitor\b/, "“display”"), (/(?i)\bdisabled\b/, "“Paused”"),
            (/(?i)\bSafe (?:\/|or) Max\b/, "the ceilings are Safe and Peak"), (/(?i)\bgrey\b/, "American “gray”"),
        ]
        var problems: [String] = []
        for entry in try Catalog.entries() where Catalog.isOurs(entry) {
            for (pattern, rule) in banned where entry.english.contains(pattern) {
                problems.append("«\(entry.english)»: \(rule)")
            }
        }
        #expect(problems.isEmpty, "\(problems)")
    }

    /// "trigger" and "headroom" are words of Advanced, the self-test and diagnostics only (DESIGN.md §1 principle 3).
    @Test func machineryWordsStayInAdvancedAndTheSelfTest() throws {
        var problems: [String] = []
        for entry in try Catalog.entries() where entry.english.contains(/(?i)\b(trigger|headroom)\b/) {
            let allowed = entry.comment.hasPrefix("Settings ▸ Advanced") || entry.comment.hasPrefix("Self-test")
                || entry.comment.contains("(Advanced only)") || entry.comment.hasPrefix("Settings ▸ About ▸ Acknowledgments")
            if !allowed { problems.append("«\(entry.english)» (\(entry.comment))") }
        }
        #expect(problems.isEmpty, "\(problems)")
    }

    /// Push buttons, sheet and alert buttons are title case (AppKit chrome, DESIGN.md §7.2, §16).
    @Test func buttonsAreTitleCase() throws {
        let small: Set = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "of", "on", "or", "the", "to", "with"]
        var problems: [String] = []
        var checked = 0
        for entry in try Catalog.entries() where entry.comment.contains("(title case") {
            let words = Catalog.words(entry.english).split { $0 == " " || $0 == "," }.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "…")) }
                .filter { !$0.isEmpty }
            checked += 1
            for (index, word) in words.enumerated() {
                let parts = word.split(separator: "-").map(String.init)            // "Self-Test"
                for part in parts where !part.isEmpty {
                    guard let first = part.first, first.isLetter else { continue }
                    let isSmall = small.contains(part) && index > 0 && index < words.count - 1
                    if !first.isUppercase && !isSmall && part != "macOS" { problems.append("«\(entry.english)»: \(part)") }
                }
            }
        }
        #expect(checked >= 30)
        #expect(problems.isEmpty, "not title case: \(problems)")
    }

    /// Row labels are sentence case: capitalized first word, then lowercase but for the names of things.
    @Test func rowLabelsAreSentenceCase() {
        let services = PaneValues.richServices()
        let names: Set = ["Dock", "Low", "Power", "Mode", "OLED", "Focus", "Overbright", "Safe", "Peak", "Fill", "Light",
                          "Automatically"]
        let skipped = Set(ShortcutsPane.order.map { ShortcutsPane.row($0).id })      // the shortcuts' own names
        var problems: [String] = []
        for value in PaneValues.values(services) where !skipped.contains(value.info.id) && !value.info.id.hasPrefix("advanced.trigger.") {
            let words = value.info.title.split(separator: " ").map(String.init)
            guard let first = words.first?.first else { continue }
            if !first.isUppercase { problems.append(value.info.title) }
            for word in words.dropFirst() where word.first?.isUppercase == true && !names.contains(word) {
                problems.append("\(value.info.title): \(word)")
            }
        }
        #expect(problems.isEmpty, "not sentence case: \(problems)")
    }

    /// The Russian glossary (ARCHITECTURE.md §8.8), wherever Russian is translated.
    @Test func translatedRussianFollowsTheGlossary() throws {
        let glossary: [(english: Regex<Substring>, russian: String)] = [
            (/\bCompatibility mode\b/, "режим совместимости"), (/\bFill Light\b/, "подсветк"), (/\bPeak\b/, "пик"),
            (/\bLess Bright\b/, "менее ярко"), (/(?i)\bextra brightness\b/, "дополнительн"),
        ]
        var problems: [String] = []
        for entry in try Catalog.entries() {
            guard let russian = entry.russian?.lowercased() else { continue }
            for term in glossary where entry.english.contains(term.english) && !russian.contains(term.russian) {
                problems.append("«\(entry.english)» → «\(russian)» lacks «\(term.russian)»")
            }
        }
        #expect(problems.isEmpty, "\(problems)")
    }
}
