// OverbrightAppShell/Help/HelpWindowController.swift — the local Help window. ARCHITECTURE.md §7.6 (a small `NSWindow`
// hosting PanelUI's `HelpView`, anchors per entry; opened from the panel, the menu, Settings and Welcome; needs no
// other window), §10.12; DESIGN.md §12.6 (answer 3 names the live Back to Standard shortcut), §0 #15 (local, no
// network). Seam written by WP0a (§10.0): `init(services:)` and `show(anchor:)` are fixed.
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Owns the Help window.
final class HelpWindowController {
    private let services: OverbrightServices
    private var window: NSWindow?

    /// The window's default size.
    static let size = CGSize(width: 520, height: 520)

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// Whether the window is on screen.
    var isShown: Bool { window?.isVisible == true }

    /// The anchor the window shows (nil: the top).
    private(set) var anchor: String?

    /// Shows Help, scrolled to `anchor` ("no-extra-range", "control-center", …; an unknown one opens at the top).
    func show(anchor: String?) {
        prepare(anchor: anchor)
        log.info("Help at \(self.anchor ?? "-", privacy: .public)")
        let window = self.window ?? makeWindow()
        self.window = window
        window.contentViewController = NSHostingController(rootView: content())
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Closes the window.
    func close() { window?.orderOut(nil) }

    /// Remembers where the window opens (a known anchor, else the top).
    func prepare(anchor: String?) { self.anchor = HelpView.resolve(anchor) }

    /// The live key caps of Back to Standard that answer 3 names (nil: cleared or not registered).
    var backToStandardKeys: String? { services.shortcuts.displayString(.standard) }

    /// The window's content now (the live shortcut in answer 3).
    func content() -> some View {
        HelpView(anchor: anchor, backToStandardKeys: backToStandardKeys)
            .overbrightThemeRoot()
    }

    /// The window's title.
    static var title: String {
        String(localized: "Overbright Help", table: "StatusMenu", bundle: .module, comment: "Help window: title")
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: Self.size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                              defer: false)
        window.title = Self.title
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("OverbrightHelp")
        return window
    }
}
