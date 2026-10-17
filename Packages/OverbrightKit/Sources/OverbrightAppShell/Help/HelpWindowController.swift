// OverbrightAppShell/Help/HelpWindowController.swift — the local Help window. ARCHITECTURE.md §7.6 (a small `NSWindow`
// hosting PanelUI's `HelpView`, anchors per entry; opened from the panel, the menu, Settings and Welcome; needs no
// other window), §10.12; DESIGN.md §12.6 (answer 3 names the live Back to Standard shortcut: `HelpView` observes the
// shortcut center, so a rebind, a clear or a registration after the window opened shows at once), §0 #15 (local, no
// network), §17 (nothing kept while closed). Seam written by WP0a (§10.0): `init(services:)` and `show(anchor:)` are
// fixed. Closing releases the window, its hosting controller and the SwiftUI tree (as Settings does); the next show
// builds them again. The frame is autosaved (not in a Debug QA run with its own defaults suite, ARCHITECTURE.md §8.5:
// AppKit's autosave writes the standard domain, so such a run keeps the frame for the run only).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Owns the Help window.
final class HelpWindowController: NSObject, NSWindowDelegate {
    /// AppKit's frame autosave name (the frame is stored under "NSWindow Frame OverbrightHelp").
    private static let frameAutosaveName = "OverbrightHelp"

    private let services: OverbrightServices
    /// False in a QA run with its own suite: AppKit's frame autosave would write the standard domain.
    private let autosavesFrame: Bool
    /// Only while Help is open: released on close.
    private(set) var window: NSWindow?
    /// Without frame autosave (a QA run with its own suite): where the window was when it closed, so the next one
    /// opens with that frame for the rest of the run, as the autosave would.
    private var closedFrame: CGRect?

    /// The window's default size.
    static let size = CGSize(width: 520, height: 520)

    /// A controller for the app's services, autosaving the frame unless this launch keeps its state in a QA suite
    /// (`ShellDefaults`).
    convenience init(services: OverbrightServices) {
        self.init(services: services, defaults: .forLaunch())
    }

    /// `defaults` is the app's `ShellDefaults` (tests pass an in-memory one, which has no frame autosave).
    init(services: OverbrightServices, defaults: ShellDefaults) {
        self.services = services
        autosavesFrame = defaults.autosavesWindowFrames
        super.init()
    }

    /// Whether the window is on screen.
    var isShown: Bool { window?.isVisible == true }

    /// The anchor the window shows (nil: the top).
    private(set) var anchor: String?

    /// Shows Help, scrolled to `anchor` ("no-extra-range", "control-center", …; an unknown one opens at the top).
    func show(anchor: String?) {
        let window = preparedWindow(anchor: anchor)
        log.info("Help at \(self.anchor ?? "-", privacy: .public)")
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// The Help window with a fresh `HelpView` at `anchor` (the open window, or a new one), centred unless it is on
    /// screen, not yet ordered in: `show(anchor:)` brings it forward; tests call this alone.
    func preparedWindow(anchor: String?) -> NSWindow {
        prepare(anchor: anchor)
        let window = self.window ?? makeWindow()
        self.window = window
        window.contentViewController = NSHostingController(rootView: content())
        if !window.isVisible { window.center() }
        return window
    }

    /// Closes the window (which releases it).
    func close() { window?.close() }

    /// Remembers where the window opens (a known anchor, else the top).
    func prepare(anchor: String?) { self.anchor = HelpView.resolve(anchor) }

    /// The live key caps of Back to Standard that answer 3 names (nil: cleared or not registered).
    var backToStandardKeys: String? { services.shortcuts.displayString(.standard) }

    /// The window's content (the live shortcut in answer 3, observed while the window is open).
    func content() -> some View {
        HelpView(anchor: anchor, shortcuts: services.shortcuts)
            .overbrightThemeRoot()
    }

    /// The window's title.
    static var title: String {
        String(localized: "Overbright Help", table: "StatusMenu", bundle: .module, comment: "Help window: title")
    }

    /// A new window, with the frame the last one had (the frame autosave; a QA run's `closedFrame`).
    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: Self.size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                              defer: false)
        window.title = Self.title
        window.isReleasedWhenClosed = false
        window.delegate = self
        if autosavesFrame {
            window.setFrameAutosaveName(Self.frameAutosaveName)
        } else if let closedFrame {
            window.setFrame(closedFrame, display: false)
        }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window, notification.object as? NSWindow === window else { return }
        // The frame is already saved: giving up the autosave name keeps it saved and lets the next window take the
        // name even if this one is still alive then (a name is unique per live window). Without the autosave, the
        // controller keeps the frame for the next window. Then the hosting controller and the window go.
        if autosavesFrame { window.setFrameAutosaveName("") } else { closedFrame = window.frame }
        window.contentViewController = nil
        window.delegate = nil
        self.window = nil
        log.info("Help closed")
    }
}
