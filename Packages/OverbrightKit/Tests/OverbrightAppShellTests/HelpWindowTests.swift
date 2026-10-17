// OverbrightAppShellTests/HelpWindowTests.swift — the Help window opens at a known anchor (else at the top) with the live
// Back to Standard shortcut in answer 3, or without it once it is cleared (DESIGN.md §12.6, §16). The window itself
// is never ordered in by a test.
import AppKit
import Observation
import OverbrightCore
@testable import OverbrightPanelUI
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

    /// The open window's answer 3 follows the shortcut center: it registers after the window opened (any `--qa-help`
    /// run), is rebound or cleared while it is open (C-PANEL-16).
    @Test func theOpenWindowObservesTheShortcut() throws {
        let center = PreviewShortcutCenter()
        center.set(.standard, nil)                                          // not registered yet when Help opens
        let view = HelpView(anchor: HelpEntry.Anchor.backToStandard, shortcuts: center)
        let answer = { view.entries.first { $0.id == HelpEntry.Anchor.backToStandard }?.answer ?? "" }
        #expect(!answer().contains("⌃⌥⌘"))
        let changed = Flag()
        withObservationTracking { _ = answer() } onChange: { changed.set() }
        center.set(.standard, KeyCombo(keyCode: 29, modifiers: [.control, .option, .command]))
        #expect(changed.isSet)                                              // the view's body would run again
        #expect(answer().contains("⌃⌥⌘0"))
        center.set(.standard, nil)
        #expect(!answer().contains("⌃⌥⌘"))
    }
}

/// A flag an observation's change handler sets (it may run on any thread).
private nonisolated final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}
