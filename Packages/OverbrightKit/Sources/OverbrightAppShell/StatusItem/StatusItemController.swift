// OverbrightAppShell/StatusItem/StatusItemController.swift — the AppKit `NSStatusItem` (not a `MenuBarExtra`, which
// macOS terminates when the user removes the extra). ARCHITECTURE.md §7.6, §10.0; DESIGN.md §4.1–§4.3, §12.7; D13.
// Seeded by WP0a (`init(services:)`, `install()`, `onClick`, placement); WP10 adds click routing (panel or toggle mode,
// right-click and ⌃-click for the menu, ⌥-click for the other action), the menu, the per-state VoiceOver label and the
// "Overbright on / off" announcement of a toggle from the icon.
import AppKit
import OverbrightCore
import OverbrightPanelUI
import os

private let log = Log.logger(.menuBar)

/// Owns the status item. Constructing it adds nothing to the menu bar; `install()` does.
final class StatusItemController: NSObject {
    private let services: OverbrightServices
    private var statusItem: NSStatusItem?
    private var symbolObservation: ObservationToken?

    /// What opening the panel does (the shell sets it: open or close the panel under the button).
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
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        show(services.boost.status.symbol)
        let boost = services.boost
        symbolObservation = OverbrightCore.observe({ boost.status.symbol }) { [weak self] symbol in self?.show(symbol) }
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

    // MARK: Clicks

    /// Runs what a click does (DESIGN.md §4.2).
    func perform(_ action: ClickRouting.Action) {
        switch action {
        case .togglePanel: onClick?()
        case .toggleMaster: toggleMaster()
        case .showMenu: showMenu()
        }
    }

    /// Turns Overbright on or off from the icon and announces it (the symbol itself is the visual feedback; a turn-on
    /// that is not ready within 0.5 s shows "Preparing…" in the HUD, which the engine publishes for `.statusItem`).
    func toggleMaster() {
        let wasOn = services.boost.status.isOn
        services.boost.toggle(source: .statusItem)
        services.announcer.announce(StatusMenuText.announcement(isOn: !wasOn), kind: .feedback)
    }

    /// The menu's rows now (also what `--qa-menu` dumps).
    func menuModel() -> StatusMenuModel { StatusMenuModel.make(services: services) }

    /// Opens the menu under the button, built fresh for the current state.
    func showMenu() {
        guard let statusItem, let button = statusItem.button else { return }
        let menu = StatusMenuRender.menu(menuModel(), services: services) { [weak self] in self?.onClick?() }
        // Attach, click, detach: AppKit then positions and tracks the menu exactly as a status menu.
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func clicked(_ sender: Any?) {
        perform(ClickRouting.action(for: NSApp.currentEvent, setting: services.settings[GeneralSettings.clickAction]))
    }

    private func show(_ state: StatusSymbolState) {
        guard let button = statusItem?.button else { return }
        button.image = StatusSymbolImage.image(for: state)
        button.setAccessibilityLabel(StatusSymbolImage.accessibilityLabel(for: state))
    }
}
