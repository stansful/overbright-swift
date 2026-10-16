// OverbrightAppShellTests/HelpWindowTests.swift — the Help window opens at a known anchor (else at the top) with the live
// Back to Standard shortcut in answer 3, or without it once it is cleared (DESIGN.md §12.6, §16). The window itself
// is never ordered in by a test.
import AppKit
import OverbrightCore
import OverbrightPanelUI
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct HelpWindowTests {
    @Test func theWindowOpensAtAKnownAnchorElseAtTheTop() {
        let controller = HelpWindowController(services: .preview())
        controller.prepare(anchor: HelpEntry.Anchor.controlCenter)
        #expect(controller.anchor == "control-center")
        controller.prepare(anchor: "no-such-answer")
        #expect(controller.anchor == nil)
        controller.prepare(anchor: nil)
        #expect(controller.anchor == nil)
        #expect(!controller.isShown)
        #expect(!HelpWindowController.title.isEmpty)
    }

    @Test func answerThreeFollowsTheLiveShortcut() throws {
        let services = OverbrightServices.preview()
        let controller = HelpWindowController(services: services)
        #expect(controller.backToStandardKeys == "⌃⌥⌘0")
        let shortcuts = try #require(services.shortcuts as? PreviewShortcutCenter)
        shortcuts.set(.standard, KeyCombo(keyCode: 29, modifiers: [.command, .shift]))
        #expect(controller.backToStandardKeys == "⇧⌘0")
        shortcuts.set(.standard, nil)
        #expect(controller.backToStandardKeys == nil)
        let size = NSHostingView(rootView: controller.content()).fittingSize
        #expect(size.width >= 480 && size.height >= 360)
    }
}
