// OverbrightAppShell/StatusItem/IconVisibilityMonitor.swift — is the status item really on screen? ARCHITECTURE.md
// §7.6; DESIGN.md §4.4. Seam written by WP0a (§10.0): `init(statusItem:)`, `start()` and `visibility` are fixed; WP10
// writes the check (3 s after launch and on every screen change: the button's window exists, is visible, its
// occlusion state contains `.visible`, and it is not behind the notch) and the icon-not-visible window.
import AppKit
import OverbrightCore

/// Watches whether macOS shows the status item.
final class IconVisibilityMonitor {
    private let statusItem: NSStatusItem

    /// The result of the last check. WP0a seam: always visible.
    private(set) var visibility: MenuBarIconVisibility = .visible

    /// A monitor for `statusItem`.
    init(statusItem: NSStatusItem) { self.statusItem = statusItem }

    /// Schedules the first check and observes screen changes. WP0a seam: does nothing.
    func start() {}
}
