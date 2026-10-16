// OverbrightAppShell/StatusItem/IconVisibilityMonitor.swift — is the status item really on screen? ARCHITECTURE.md
// §7.6; DESIGN.md §4.4. Seam written by WP0a (§10.0): `init(statusItem:)`, `start()` and `visibility` are fixed. WP10
// writes the check: 3 s after launch, on every screen change and whenever the button's window changes occlusion
// (`IconVisibilityCheck`), and reports changes through `onChange` (the shell forwards them to
// `ShellAppControl.updateIconVisibility` and `IconNotVisibleWindowController.showIfNeeded`, WP13's wiring).
// Event-driven: no polling (DESIGN.md §17).
import AppKit
import OverbrightCore
import os

private let log = Log.logger(.menuBar)

/// Watches whether macOS shows the status item.
final class IconVisibilityMonitor {
    private let statusItem: NSStatusItem
    private var observers: [any NSObjectProtocol] = []
    private var firstCheck: Task<Void, Never>?

    /// The result of the last check (visible until the first check ran).
    private(set) var visibility: MenuBarIconVisibility = .visible

    /// Called on the main actor whenever `visibility` changes.
    var onChange: ((MenuBarIconVisibility) -> Void)?

    /// The delay of the first check after launch (MenuBarAgent places the item after launch, ARCHITECTURE.md §7.6).
    static let firstCheckDelay: Duration = .seconds(3)

    /// A monitor for `statusItem`.
    init(statusItem: NSStatusItem) { self.statusItem = statusItem }

    isolated deinit {
        firstCheck?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    /// Schedules the first check and observes screen changes and the button window's occlusion.
    func start() {
        guard observers.isEmpty else { return }
        firstCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.firstCheckDelay)
            guard !Task.isCancelled else { return }
            self?.check()
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }                                       // queue: .main
        })
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                            object: statusItem.button?.window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }                                       // queue: .main
        })
    }

    /// Checks now and reports a change.
    func check() {
        let window = statusItem.button?.window.map { window in
            IconVisibilityCheck.Window(isVisible: window.isVisible, isUnoccluded: window.occlusionState.contains(.visible),
                                       frame: window.frame)
        }
        let result = IconVisibilityCheck.evaluate(window: window, screens: NSScreen.screens.map(IconVisibilityCheck.Screen.init),
                                                  showsIcon: statusItem.isVisible)
        guard result != visibility else { return }
        visibility = result
        log.info("menu bar icon: \(String(describing: result), privacy: .public)")
        onChange?(result)
    }
}
