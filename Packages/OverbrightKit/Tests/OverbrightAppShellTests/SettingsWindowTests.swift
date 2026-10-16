// OverbrightAppShellTests/SettingsWindowTests.swift — the Settings window's lifetime (ARCHITECTURE.md §7.6; DESIGN.md
// §7.1, §7.8): closing it releases the window, its hosting controller and the SwiftUI tree, while the controller keeps
// the `SettingsSession`, so opening it again at a pane shows that pane with the search of before, where the window was
// (in-memory defaults have no frame autosave, as in a QA run); the Undo offer of Reset All ends with the window. Nothing
// is ordered in and nothing is activated: `preparedWindow(at:)` builds the window `show(pane:)` would bring forward.
// Ported from Cranny's SettingsWindowTests (the owner's MIT code).
import AppKit
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell
@testable import OverbrightSettingsUI

@MainActor @Suite struct SettingsWindowTests {
    @Test func closingSettingsReleasesTheWindowAndReopeningKeepsTheSession() async throws {
        _ = NSApplication.shared
        let services = OverbrightServices.preview()
        services.app = nil                                                        // Reset All on the store itself
        let defaults = ShellDefaults.inMemory
        let controller = SettingsWindowController(services: services, defaults: defaults)
        let frame = CGRect(x: 40, y: 60, width: 900, height: 640)
        weak var closedWindow: NSWindow?
        weak var closedHost: NSViewController?
        let session = try autoreleasepool {
            let window = controller.preparedWindow(at: "about")
            window.contentView?.layoutSubtreeIfNeeded()                           // the SwiftUI tree is built
            closedWindow = window
            closedHost = window.contentViewController
            #expect(closedHost != nil)
            #expect(window.contentMinSize == CGSize(width: 780, height: 560))
            let session = try #require(controller.session)
            #expect(session.currentPane == .about)
            session.query = "battery"
            session.resetAll.resetAll()
            #expect(session.canUndoReset)
            window.setFrame(frame, display: false)                                // the person moved it
            window.close()
            return session
        }
        #expect(controller.window == nil && controller.session === session)
        #expect(!session.canUndoReset)                                            // the Undo offer ended with the window
        for _ in 0..<150 where closedWindow != nil || closedHost != nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(closedWindow == nil, "the closed window is still alive")
        #expect(closedHost == nil, "the closed window's hosting controller is still alive")

        // Reopened at a deep link: a new window around the same session, on that pane, with the search of before.
        let reopened = controller.preparedWindow(at: "advanced#resetAll")
        #expect(controller.session === session && controller.window === reopened)
        #expect(session.currentPane == .advanced && session.query == "battery")
        #expect(reopened.frame == frame)                                          // where the closed one was
        let title = SettingsPane.pane(.advanced).title                            // in the test run's language
        reopened.contentView?.layoutSubtreeIfNeeded()
        for _ in 0..<150 where reopened.title != title { try await Task.sleep(for: .milliseconds(20)) }
        #expect(reopened.title == title)                                          // the new tree shows the pane

        // While it is open, showing Settings again navigates the same window.
        #expect(controller.preparedWindow(at: "displays") === reopened && session.currentPane == .displays)

        // Closed and opened without a pane: the pane shown last (remembered in the app's defaults, not a setting).
        for _ in 0..<150 where defaults.defaults.string(forKey: SettingsWindowController.lastPaneKey) != "displays" {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(defaults.defaults.string(forKey: SettingsWindowController.lastPaneKey) == "displays")
        reopened.close()
        let third = controller.preparedWindow(at: nil)
        #expect(third !== reopened && session.currentPane == .displays)
        third.close()
    }

    /// The first open of a run, without a pane, restores the pane shown last.
    @Test func theFirstOpenRestoresTheLastPane() throws {
        _ = NSApplication.shared
        let defaults = ShellDefaults.inMemory
        defaults.defaults.set("fillLight", forKey: SettingsWindowController.lastPaneKey)
        let controller = SettingsWindowController(services: .preview(), defaults: defaults)
        let window = controller.preparedWindow(at: nil)
        #expect(try #require(controller.session).currentPane == .fillLight)
        window.close()
    }

    /// Debug QA `-OverbrightQASettingsMenuItem`: the app menu's ⌘, item is found by its key equivalent (⌘, alone, not
    /// ⌘⇧,) and its own action runs; a menu without one reports that. Built here, nothing is shown.
    @Test func theQAHookPerformsTheAppMenusCommandCommaItem() {
        final class Target: NSObject {
            var fired: [String] = []
            @objc func fire(_ sender: NSMenuItem) { fired.append(sender.title) }
        }
        let target = Target()
        func item(_ title: String, _ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(Target.fire(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            return item
        }
        let appMenu = NSMenu(title: "Overbright")
        appMenu.items = [item("About", "", []), item("Other…", ",", [.command, .shift]), item("Settings…", ",", .command),
                         item("Quit", "q", .command)]
        let main = NSMenu(title: "Main")
        let top = NSMenuItem(title: "Overbright", action: nil, keyEquivalent: "")
        top.submenu = appMenu
        main.addItem(top)
        #expect(SettingsWindowController.performSettingsMenuItem(in: main))
        #expect(target.fired == ["Settings…"])
        appMenu.removeItem(at: 2)
        #expect(!SettingsWindowController.performSettingsMenuItem(in: main))
        #expect(!SettingsWindowController.performSettingsMenuItem(in: nil))
        #expect(target.fired == ["Settings…"])
    }
}
