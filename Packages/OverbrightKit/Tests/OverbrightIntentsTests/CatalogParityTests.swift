// OverbrightIntentsTests/CatalogParityTests.swift — the app-target adapters cannot be unit-tested (ARCHITECTURE.md
// §7.7), so their sources are checked here (§10.10): every localizable literal of App/Intents, Shared and Controls is a
// key of the catalog its bundle reads (the shared control intent in both the app's and the extension's), no catalog
// key is unused or uncommented, every string of DESIGN.md §12.8 is there, every `perform()` is `@MainActor` and a
// one-line forward, no App Group exists anywhere, and the extension imports nothing of OverbrightKit but the Channel.
import Foundation
import Testing

@Suite struct CatalogParityTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    // MARK: Keys

    @Test func everyAppLiteralIsAKeyOfTheAppCatalogs() throws {
        let literals = try Self.literals(in: ["App/Intents", "Shared"])
        let phrases = literals.filter { $0.contains("${applicationName}") }
        let localizable = try Self.keys(of: "App/Localizable.xcstrings")
        let shortcuts = try Self.keys(of: "App/AppShortcuts.xcstrings")
        #expect(literals.count > 40)
        #expect(literals.subtracting(phrases).subtracting(localizable).isEmpty,
                "missing in App/Localizable.xcstrings: \(literals.subtracting(phrases).subtracting(localizable).sorted())")
        #expect(phrases.subtracting(shortcuts).isEmpty, "missing in App/AppShortcuts.xcstrings: \(phrases.subtracting(shortcuts).sorted())")
        #expect(localizable.subtracting(literals).isEmpty, "unused in App/Localizable.xcstrings: \(localizable.subtracting(literals).sorted())")
        #expect(shortcuts == phrases)
    }

    @Test func everyControlLiteralIsAKeyOfTheExtensionCatalog() throws {
        let literals = try Self.literals(in: ["Controls", "Shared"])
        let keys = try Self.keys(of: "Controls/Localizable.xcstrings")
        #expect(literals == keys, "Controls/Localizable.xcstrings ≠ the extension’s literals: \(literals.symmetricDifference(keys).sorted())")
        let shared = try Self.literals(in: ["Shared"])
        #expect(!shared.isEmpty)
        #expect(shared.isSubset(of: try Self.keys(of: "App/Localizable.xcstrings")))
    }

    @Test func everyKeyHasATranslatorComment() throws {
        for catalog in ["App/Localizable.xcstrings", "App/AppShortcuts.xcstrings", "Controls/Localizable.xcstrings",
                        "Packages/OverbrightKit/Sources/OverbrightIntents/Resources/Localizable.xcstrings"] {
            for (key, entry) in try Self.entries(of: catalog) {
                let comment = entry["comment"] as? String ?? ""
                let surface = ["Shortcuts app", "Focus filter", "Control Center"].contains { comment.hasPrefix($0) }
                #expect(surface, "\(catalog): \(key) needs a “<Surface>: <purpose>” comment")
            }
        }
    }

    @Test func everyStringOfTheDesignIsInItsCatalog() throws {
        // DESIGN.md §12.8, with typographic apostrophes (scripts/lib/lint-copy.py).
        let app = try Self.keys(of: "App/Localizable.xcstrings")
        let titles = ["Turn Overbright On or Off", "Turn On Overbright", "Turn Off Overbright", "Set Extra Brightness",
                      "Dim Displays", "Pause Overbright", "Resume Overbright", "Get Overbright State", "Back to Standard"]
        let descriptions = [
            "Turns extra brightness on or off.", "Turns Overbright on. Each display uses its own level.",
            "Turns Overbright off. Your displays return to Standard.",
            "Sets the extra brightness of a display, or of every display. Each display stops at its own limit.",
            "Dims a display, or every display, below the macOS minimum.", "Pauses extra brightness for a while.",
            "Ends a pause.", "Tells whether Overbright is on, and the level of each display.",
            "Turns Overbright off at once. Your levels are kept for next time.",
        ]
        let parameters = ["Display", "%lld Displays", "All Displays", "Level", "Indoor", "Bright Room", "Sunlight", "Max",
                          "Multiplier", "Brightness", "Duration"]
        let focus = ["Overbright", "Leave Alone", "Off", "On", "Overbright: Leave Alone", "Overbright: Off",
                     "Overbright: On at Bright Room"]
        let summaries = ["Set extra brightness of ${display} to ${level}", "Dim ${display} to ${percent}",
                         "Pause Overbright for ${duration}"]
        let shortTitles = ["Turn On or Off", "Back to Standard"]
        let expected = Set(titles + descriptions + parameters + focus + summaries + shortTitles)
        #expect(expected.subtracting(app).isEmpty, "missing: \(expected.subtracting(app).sorted())")
        // The type's plural (DESIGN.md §12.8: "Displays") has its plural forms, English included.
        let plural = try #require(try Self.entries(of: "App/Localizable.xcstrings")["%lld Displays"])
        let english = (plural["localizations"] as? [String: Any])?["en"] as? [String: Any]
        let forms = ((english?["variations"] as? [String: Any])?["plural"] as? [String: Any]) ?? [:]
        #expect(Set(forms.keys) == ["one", "other"])
        #expect(try Self.keys(of: "App/AppShortcuts.xcstrings") == ["Turn ${applicationName} on or off",
                                                                   "${applicationName} back to Standard"])
        #expect(try Self.keys(of: "Controls/Localizable.xcstrings").isSuperset(of: ["Overbright", "Extra brightness"]))
        let errors: Set = ["Overbright is still starting. Try again in a moment.", "That display isn’t connected.",
                           "This display can’t show extra brightness.", "This display can’t be dimmed.",
                           "Overbright is on.", "Overbright is off."]
        let router = try Self.keys(of: "Packages/OverbrightKit/Sources/OverbrightIntents/Resources/Localizable.xcstrings")
        #expect(errors.subtracting(router).isEmpty, "missing in the Intents catalog: \(errors.subtracting(router).sorted())")
    }

    // MARK: Source rules (D18)

    @Test func everyPerformIsMainActorAndAOneLineForward() throws {
        var performs = 0
        for file in try Self.swiftFiles(in: ["App/Intents", "Shared"]) {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("func perform()") {
                performs += 1
                let name = file.lastPathComponent
                #expect(lines[index - 1].trimmingCharacters(in: .whitespaces) == "@MainActor", "\(name): perform() is not @MainActor")
                let raw = lines[(index + 1)...].map { $0.trimmingCharacters(in: .whitespaces) }.prefix { $0 != "}" }
                let branches = 1 + raw.filter { $0.hasPrefix("#else") || $0.hasPrefix("#elseif") }.count   // #if arms
                let body = raw.filter { !$0.hasPrefix("#") && !$0.isEmpty }
                #expect(body.last?.hasPrefix("return ") == true, "\(name): perform() ends with its result")
                let forwards = body.dropLast()
                #expect(forwards.count == branches, "\(name): perform() is one forwarding line, not \(forwards.count)")
                #expect(forwards.allSatisfy { $0.contains("router.") || $0.contains("ControlHandOff.") }, "\(name): \(forwards)")
            }
        }
        #expect(performs == 11)             // nine intents, the Focus filter and the control's action
    }

    @Test func noAppGroupAnywhere() throws {
        let files = try Self.files(in: ["App", "Controls", "Shared", "Overbright.xcodeproj"]) { url in
            ["swift", "entitlements", "plist", "pbxproj"].contains(url.pathExtension)
        }
        #expect(files.count > 10)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("application-groups"), "\(file.lastPathComponent) claims an App Group")
            #expect(!text.contains("containerURL(forSecurityApplicationGroupIdentifier"), "\(file.lastPathComponent)")
            #expect(!text.contains("UserDefaults(" + "suiteName:"), "\(file.lastPathComponent)")   // split: Core's lint
        }
    }

    @Test func theExtensionUsesOnlyTheChannel() throws {
        let allowed: Set = ["AppIntents", "AppKit", "SwiftUI", "WidgetKit", "Foundation", "OverbrightChannel"]
        for file in try Self.swiftFiles(in: ["Controls", "Shared"]) {
            let text = try String(contentsOf: file, encoding: .utf8)
            var inAppOnlyBlock = false
            for line in text.components(separatedBy: "\n") {
                if line.hasPrefix("#if OVERBRIGHT_APP") { inAppOnlyBlock = true } else if line.hasPrefix("#endif") || line.hasPrefix("#else") { inAppOnlyBlock = false }
                guard !inAppOnlyBlock, line.hasPrefix("import ") else { continue }
                let module = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "\(file.lastPathComponent) imports \(module) into the extension")
            }
        }
        let project = try String(contentsOf: Self.repository.appending(path: "Overbright.xcodeproj/project.pbxproj"),
                                 encoding: .utf8)
        let target = try #require(project.range(of: "/* OverbrightControls */ = {\n\t\t\tisa = PBXNativeTarget;"))
        let section = project[target.lowerBound...].prefix { $0 != "}" }
        #expect(section.contains("OverbrightControlsKit"))
        #expect(!section.contains("OverbrightAppShell"))
    }

    // MARK: Helpers

    /// The localizable string literals of the Swift files under `folders`, as catalog keys: `\(\.$p)` → `${p}`,
    /// `\(.applicationName)` → `${applicationName}`, any other interpolation → `%@`. Identifiers such as symbol names
    /// ("sun.max") and entity IDs ("all-displays") are not localizable; comment lines are skipped.
    private static func literals(in folders: [String]) throws -> Set<String> {
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        let parameter = try NSRegularExpression(pattern: #"\\\(\\\.\$([A-Za-z]+)\)"#)
        let applicationName = try NSRegularExpression(pattern: #"\\\(\.applicationName\)"#)
        let other = try NSRegularExpression(pattern: #"\\\([^)]*\)"#)
        let identifier = try NSRegularExpression(pattern: #"^[a-z][a-z0-9]*([.-][a-z0-9]+)+$"#)
        var found = Set<String>()
        for file in try swiftFiles(in: folders) {
            for line in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                let range = NSRange(line.startIndex..., in: line)
                for match in literal.matches(in: line, range: range) {
                    guard let inner = Range(match.range(at: 1), in: line) else { continue }
                    var key = String(line[inner])
                    key = replace(parameter, in: key, with: "\\${$1}")
                    key = replace(applicationName, in: key, with: "\\${applicationName}")
                    key = replace(other, in: key, with: "%@")
                    if !key.isEmpty, identifier.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) == nil {
                        found.insert(key)
                    }
                }
            }
        }
        return found
    }

    private static func replace(_ pattern: NSRegularExpression, in text: String, with template: String) -> String {
        pattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    private static func entries(of catalog: String) throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: repository.appending(path: catalog))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["strings"] as? [String: [String: Any]])
    }

    private static func keys(of catalog: String) throws -> Set<String> { Set(try entries(of: catalog).keys) }

    private static func swiftFiles(in folders: [String]) throws -> [URL] {
        try files(in: folders) { $0.pathExtension == "swift" }
    }

    private static func files(in folders: [String], where include: (URL) -> Bool) throws -> [URL] {
        try folders.flatMap { folder -> [URL] in
            let root = repository.appending(path: folder, directoryHint: .isDirectory)
            let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            return enumerator.compactMap { $0 as? URL }.filter(include).sorted { $0.path < $1.path }
        }
    }
}
