// OverbrightAppShell/StatusItem/StatusItemController.swift — the AppKit `NSStatusItem` (not a `MenuBarExtra`, which
// macOS terminates when the user removes the extra). ARCHITECTURE.md §7.6, §10.0; DESIGN.md §4.1–§4.2; D13.
// Seeded by WP0a: `init(services:)` is fixed; the WP0a body installs the item with the code-drawn symbol and routes a
// click to `onClick` (the panel). WP10 owns `StatusItem/` and adds the right-click menu, ⌥-click, the toggle mode and
// the per-state accessibility label.
import AppKit
import OverbrightCore
import os

private let log = Log.logger(.menuBar)

/// Owns the status item. Constructing it adds nothing to the menu bar; `install()` does.
final class StatusItemController: NSObject {
    private let services: OverbrightServices
    private var statusItem: NSStatusItem?
    private var symbolObservation: ObservationToken?

    /// What a click does (the shell sets it: open or close the panel).
    var onClick: (() -> Void)?

    /// A controller for the app's services.
    init(services: OverbrightServices) {
        self.services = services
        super.init()
    }

    /// The status item's button, the panel's anchor (nil while the item is not installed).
    var button: NSStatusBarButton? { statusItem?.button }

    /// The installed item (the icon visibility monitor watches it).
    var item: NSStatusItem? { statusItem }

    /// Adds the item to the menu bar with the symbol of the engine's current state. Called once, never in a
    /// command-line mode.
    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusSymbolImage.image(for: services.boost.status.symbol)
        item.button?.setAccessibilityLabel("Overbright")
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        let boost = services.boost
        symbolObservation = OverbrightCore.observe({ boost.status.symbol }) { [weak self] symbol in
            self?.statusItem?.button?.image = StatusSymbolImage.image(for: symbol)
        }
    }

    /// Shows or hides the item (General ▸ Show menu bar icon).
    func setVisible(_ visible: Bool) { statusItem?.isVisible = visible }

    /// The button's window frame once the item is placed in a menu bar; nil before and while the item is not
    /// installed. Placed means on a screen (`PanelPlacement.isPlaced`): right after `install()` the window is 0 pt
    /// high, and on macOS 27.0.1 it then passes through frames just below and just above the primary screen while
    /// MenuBarAgent places the item.
    var placedFrame: CGRect? {
        guard let frame = statusItem?.button?.window?.frame,
              PanelPlacement.isPlaced(frame, in: PanelPlacement.currentScreens) else { return nil }
        return frame
    }

    /// Waits until the item is placed, at most `limit` (the launch UI anchors the panel to it); true when it is. When
    /// it is not, the panel opens at the top-right of the main screen and follows the button once it is placed.
    @discardableResult
    func waitUntilPlaced(atMost limit: Duration) async -> Bool {
        let step: Duration = .milliseconds(50)
        var waited: Duration = .zero
        while statusItem != nil, placedFrame == nil, waited < limit {
            try? await Task.sleep(for: step)
            waited += step
        }
        let placed = placedFrame != nil
        log.info("status item placed: \(placed, privacy: .public) after \(waited.timeInterval, privacy: .public) s")
        return placed
    }

    @objc private func clicked(_ sender: Any?) {
        onClick?()
    }
}
