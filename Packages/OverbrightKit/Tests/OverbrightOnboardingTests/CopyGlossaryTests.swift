// OverbrightOnboardingTests/CopyGlossaryTests.swift — Welcome's copy names things the way the rest of Overbright does
// (DESIGN.md §16 vocabulary and voice, §8 exact English, §12.8 the Shortcuts action's title; ARCHITECTURE.md §8.8 one
// comment per key, "<Surface>: <purpose>"). Checked on the module's String Catalog itself, so every key counts,
// including ones added later; and every string the steps show is a key of it (the catalog is in sync with the code).
// Translations are WP15's; this suite checks the English source (Cranny's suite checked Russian, its pivot language).
import Foundation
import Testing
@testable import OverbrightOnboarding

/// The module's catalog: key → (comment, localizations).
private struct Catalog {
    let entries: [String: [String: Any]]

    /// `Sources/OverbrightOnboarding/Resources/Localizable.xcstrings`, read from the source tree.
    static func load(filePath: String = #filePath) throws -> Catalog {
        let url = URL(filePath: filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/OverbrightOnboarding/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: [String: Any]])
        return Catalog(entries: strings)
    }

    var keys: [String] { entries.keys.sorted() }

    func comment(_ key: String) -> String { entries[key]?["comment"] as? String ?? "" }
}

/// Every string field of a step's `Copy` (Mirror: new fields are checked without editing this suite).
private func strings(of copy: Any) -> [String] {
    Mirror(reflecting: copy).children.compactMap { $0.value as? String }
}

@MainActor @Suite struct CopyGlossaryTests {
    /// The words of every step in English (whatever language the test process runs in).
    static var stepStrings: [String] {
        strings(of: HelloStep.Copy.localized(in: englishBundle))
            + strings(of: DisplaysStep.Copy.localized(in: englishBundle))
            + strings(of: DefaultsStep.Copy.localized(in: englishBundle))
            + strings(of: FindItStep.Copy.localized(in: englishBundle))
            + strings(of: DoneStep.Copy.localized(in: englishBundle))
    }

    @Test func everyStringTheStepsShowIsACatalogKey() throws {
        let catalog = try Catalog.load()
        let shown = Self.stepStrings
        #expect(shown.count >= 30)
        for text in shown { #expect(catalog.entries[text] != nil, "missing from the catalog: \(text)") }
    }

    /// Every key has one comment that names its surface (Welcome, or VoiceOver for what only VoiceOver speaks).
    @Test func everyKeyHasASurfaceComment() throws {
        let catalog = try Catalog.load()
        for key in catalog.keys {
            let comment = catalog.comment(key)
            #expect(comment.hasPrefix("Welcome") || comment.hasPrefix("VoiceOver: "), "\(key): \(comment)")
        }
    }

    /// DESIGN.md §16: the words the product never uses in copy, and the typography of American English.
    @Test func theCopyUsesTheGlossary() throws {
        let never: [(pattern: String, why: String)] = [
            (#"\bboost"#, "“extra brightness”, never “boost”"), (#"\b[HX]DR mode"#, "no “HDR mode”"),
            (#"\bEDR\b"#, "no “EDR” outside Advanced"), (#"gamma"#, "no “gamma”"), (#"headroom"#, "“extra range”"),
            (#"\bmonitor"#, "“display”"), (#"\bdimmer\b"#, "“Less Bright”"), (#"night mode"#, "“Dim below minimum”"),
            (#"panic|reset brightness"#, "“Back to Standard”"), (#"fallback|overlay"#, "no “fallback” or “overlay”"),
            (#"ring light"#, "“Fill Light”"), (#"normal mode|100 ?%"#, "“Standard”"),
            (#"\bdisabled\b|turns off for"#, "“Pause / Paused”"), (#"Launchpad"#, "removed in macOS 26"),
            (#"!"#, "no exclamation marks"), (#"\.\.\."#, "one-character ellipsis …"),
            (#"'"#, "typographic apostrophe ’"), ("\"", "typographic quotes “ ”"),
            (#"[⌃⌥⇧⌘]"#, "key caps are never literal (§16)"), (#"System Settings ▸"#, "name System Settings by pane"),
        ]
        for key in try Catalog.load().keys {
            for rule in never {
                #expect(key.range(of: rule.pattern, options: [.regularExpression, .caseInsensitive]) == nil,
                        "\(key): \(rule.why)")
            }
        }
    }

    /// The exact English of DESIGN.md §8 (headlines, bodies, captions, switches, option cards, rows).
    @Test func theStepsSayWhatTheDesignSays() {
        let shown = Set(Self.stepStrings)
        let design = [
            "Use your display’s extra range",
            "Your display can show light brighter than ordinary white. Overbright lets everyday content use that range, so the screen stays readable in a bright room or in sunlight. For the most light, turn your display brightness all the way up first; Overbright adds to it. Drag the divider to compare.",
            "Only this card is brighter. It’s a preview: the real result depends on your display.",
            "None of your displays has extra range right now. The next step shows why.",
            "This display has no extra range right now. Move this window to another display to compare.",
            "Your displays", "Overbright checks what each display can do.", "Use extra brightness",
            "How Overbright behaves",
            "Extra light uses more power, so Overbright steps back on its own. Choose how it starts.",
            "Pause in Low Power Mode", "Pause for full-screen video", "It also backs off when your Mac gets warm.",
            "Open and turn on", "Open, keep off", "Recommended", "Don’t open at login",
            "Where to find Overbright", "Overbright lives in the menu bar.",
            "Click for the panel, right-click for the menu", "Turn on or off", "Back to Standard",
            "Dim Below Minimum On or Off", "Shortcuts app and Control Center",
            "Open Overbright again from Finder or Spotlight to see Settings.",
            "You’re set", "Check for updates on GitHub",
        ]
        for text in design { #expect(shown.contains(text), "\(text)") }
    }

    /// The Run Shortcut recipe names the Shortcuts action by its title (DESIGN.md §12.8) and Control Center's control
    /// by macOS's name (§7.6).
    @Test func theRecipeNamesTheActionAndTheControl() {
        let recipe = FindItStep.Copy.localized(in: englishBundle).recipe
        #expect(recipe.contains("Turn Overbright On or Off") && recipe.contains("Run Shortcut"))
        #expect(recipe.contains("Control Center"))
    }

    /// Welcome's buttons are AppKit chrome: title case (DESIGN.md §12, §16); its labels and sentences are not.
    @Test func buttonsAreTitleCaseAndLabelsSentenceCase() {
        let footer = WelcomeFooter.Labels.localized(in: englishBundle)
        for title in [footer.quit, footer.back, footer.proceed, footer.done, footer.turnOn] {
            let words = title.split(separator: " ")
            #expect(words.allSatisfy { $0.first?.isUppercase == true }, "\(title)")
        }
        let defaults = DefaultsStep.Copy.localized(in: englishBundle)
        for label in [defaults.lowPower, defaults.fullScreenVideo, defaults.openAndTurnOn, defaults.dontOpen] {
            let words = label.split(separator: " ").dropFirst()
            #expect(words.contains { $0.first?.isLowercase == true }, "\(label)")
        }
    }
}
