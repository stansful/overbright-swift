// OverbrightHotKeysTests/KeyCapLayoutTests.swift — key caps follow the keyboard layout (DESIGN.md §12.5, §16;
// ARCHITECTURE.md §8.8): the sample combinations (`SampleShortcuts`, the suggestions of D17 before every shortcut
// shipped unbound) in the US, German and French layouts, read from the layouts installed with macOS (read-only: no
// input source is selected or enabled). The same function draws the menu's key equivalents, the recorder and
// `ShortcutCenter.displayString`.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightHotKeys

@MainActor private func layout(_ name: String) throws -> KeyCombo.KeyboardLayout {
    try #require(KeyCombo.KeyboardLayout.named("com.apple.keylayout.\(name)"), "macOS ships the \(name) layout")
}

/// The caps of the sample combination of `id` in `layout`.
private func caps(_ id: ShortcutID, _ layout: KeyCombo.KeyboardLayout) throws -> String {
    let combo = try #require(SampleShortcuts.bindings[id] ?? nil)
    return combo.keyCaps(in: layout)
}

@MainActor @Suite struct KeyCapLayoutTests {
    @Test func usLayoutShowsTheSampleKeyCaps() throws {
        let us = try layout("US")
        #expect(try caps(.toggle, us) == "⌃⌥⌘B")
        #expect(try caps(.brighter, us) == "⌃⌥⌘=")
        #expect(try caps(.lessBright, us) == "⌃⌥⌘-")
        #expect(try caps(.standard, us) == "⌃⌥⌘0")
        #expect(try caps(.dimToggle, us) == "⌃⌥⌘9")
    }

    /// German: the key at kVK_ANSI_Equal is ´ and at kVK_ANSI_Minus is ß (which must not become "SS").
    @Test func germanLayoutShowsTheKeysThatSitThere() throws {
        let german = try layout("German")
        #expect(try caps(.toggle, german) == "⌃⌥⌘B")
        #expect(try caps(.brighter, german) == "⌃⌥⌘´")
        #expect(try caps(.lessBright, german) == "⌃⌥⌘ß")
        #expect(try caps(.standard, german) == "⌃⌥⌘0")
        #expect(KeyCombo(keyCode: 6, modifiers: [.command]).keyCaps(in: german) == "⌘Y")    // QWERTZ: Z position
    }

    /// French (AZERTY): the number row types symbols and accented letters, and A sits at the Q position.
    @Test func frenchLayoutShowsTheKeysThatSitThere() throws {
        let french = try layout("French")
        #expect(try caps(.toggle, french) == "⌃⌥⌘B")
        #expect(try caps(.brighter, french) == "⌃⌥⌘-")
        #expect(try caps(.lessBright, french) == "⌃⌥⌘)")
        #expect(try caps(.standard, french) == "⌃⌥⌘À")
        #expect(try caps(.dimToggle, french) == "⌃⌥⌘Ç")
        #expect(KeyCombo(keyCode: 12, modifiers: [.command]).keyCaps(in: french) == "⌘A")   // AZERTY: Q position
    }

    /// Menus show the command layer: a Russian layout still reads Latin letters.
    @Test func nonLatinLayoutsShowTheCommandLayer() throws {
        let russian = try layout("Russian")
        #expect(try caps(.toggle, russian) == "⌃⌥⌘B")
    }

    @Test func namedKeysAndModifierOrderDoNotDependOnTheLayout() throws {
        let us = try layout("US")
        let all = KeyCombo(keyCode: 35, modifiers: [.command, .shift, .option, .control])
        #expect(all.keyCaps(in: us) == "⌃⌥⇧⌘P")
        #expect(KeyCombo(keyCode: 122, modifiers: []).keyCaps(in: nil) == "F1")
        #expect(KeyCombo(keyCode: 123, modifiers: [.control]).keyCaps(in: nil) == "⌃←")
        #expect(KeyCombo(keyCode: 53, modifiers: [.command]).keyCaps(in: nil) == "⌘⎋")
        #expect(KeyCombo(keyCode: 49, modifiers: [.option]).keyCaps(in: us, spaceName: "Space") == "⌥Space")
        #expect(KeyCombo.keyName(11, in: nil) == "#11")                                  // no layout: the code
    }

    /// `displayString` renders a registered shortcut through the center's layout, and nothing for one that is off.
    @Test func displayStringUsesTheCentersLayout() async throws {
        let german = try layout("German")
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[ShortcutSettings.bindings] = SampleShortcuts.bindings                    // none ships bound (D17)
        let center = HotKeyCenter(settings: settings, registrar: FakeRegistrar(), layout: { german })
        await center.start()
        #expect(center.displayString(.brighter) == "⌃⌥⌘´")
        #expect(center.displayString(.max) == nil)
        center.set(.brighter, nil)
        #expect(center.displayString(.brighter) == nil)
        await center.stop()
    }
}
