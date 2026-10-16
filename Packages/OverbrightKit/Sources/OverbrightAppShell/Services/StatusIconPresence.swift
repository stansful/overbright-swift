// OverbrightAppShell/Services/StatusIconPresence.swift — the status item in the menu bar, its visibility check and the
// "icon isn't visible" window, wired together. ARCHITECTURE.md §7.6 (status item, visibility check 3 s after launch
// and on every screen change), §10.15; DESIGN.md §4.4 (hide the icon, icon not visible at most once per version).
//
// The item is always installed and only made invisible while General ▸ Show menu bar icon is off, so turning it back
// on needs no new item, and the visibility check reports "hidden by the user" rather than "not visible". The monitor's
// changes go to `ShellAppControl` (Settings' warning row, the launch UI) and to the window, which shows itself at most
// once per app version and never for an icon the user hid.
import AppKit
import OverbrightCore

/// The status item, its visibility monitor and the icon-not-visible window.
final class StatusIconPresence {
    /// The status item.
    let statusItem: StatusItemController
    private let notice: IconNotVisibleWindowController
    private var monitor: IconVisibilityMonitor?
    private var recheck: Task<Void, Never>?

    /// Called with every visibility change the monitor finds.
    var onVisibilityChange: ((MenuBarIconVisibility) -> Void)?

    /// A presence for `services`; nothing is in the menu bar until `install(visible:)`.
    init(services: OverbrightServices, statusItem: StatusItemController) {
        self.statusItem = statusItem
        notice = IconNotVisibleWindowController(services: services)
    }

    /// Whether the icon-not-visible window is on screen.
    var isNoticeShown: Bool { notice.isShown }

    /// Installs the item (shown or hidden) and starts the visibility check (once).
    func install(visible: Bool) {
        statusItem.install()
        statusItem.setVisible(visible)
        guard monitor == nil, let item = statusItem.item else { return }
        let monitor = IconVisibilityMonitor(statusItem: item)
        monitor.onChange = { [weak self] visibility in self?.visibilityChanged(visibility) }
        monitor.start()
        self.monitor = monitor
    }

    /// Shows or hides the item; returns the visibility to report now. Hiding checks at once ("hidden by the user");
    /// showing reports visible and checks again after `IconVisibilityMonitor.firstCheckDelay`, because MenuBarAgent
    /// places a shown item a moment later and an earlier check would call it not visible.
    @discardableResult
    func setVisible(_ visible: Bool) -> MenuBarIconVisibility {
        if statusItem.item == nil { install(visible: visible) } else { statusItem.setVisible(visible) }
        recheck?.cancel()
        guard visible else {
            monitor?.check()
            return .hiddenByUser
        }
        recheck = Task { [weak self] in
            try? await Task.sleep(for: IconVisibilityMonitor.firstCheckDelay)
            guard !Task.isCancelled else { return }
            self?.monitor?.check()
        }
        return .visible
    }

    /// The monitor's result now (`.visible` until the first check).
    var visibility: MenuBarIconVisibility { monitor?.visibility ?? .visible }

    private func visibilityChanged(_ visibility: MenuBarIconVisibility) {
        onVisibilityChange?(visibility)
        notice.showIfNeeded(visibility)
    }
}
