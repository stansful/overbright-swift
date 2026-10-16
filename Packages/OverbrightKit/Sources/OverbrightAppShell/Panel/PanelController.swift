// OverbrightAppShell/Panel/PanelController.swift — opens and closes the panel under the status item.
// ARCHITECTURE.md §7.6, §10.0; DESIGN.md §5.1; D13. Seeded by WP0a: `init(services:)` and `toggle(from:)` are fixed;
// the WP0a body shows `PlaceholderPanelView` in an `OverbrightPanel`, anchored to the status button's window frame
// (never `NSStatusBar.system.thickness`, which says 22 pt while the bar is 30 pt on macOS 27), closing on an outside
// click or Esc. `PanelPlacement` keeps the panel on screen while the button is not placed yet, and the panel follows
// the button's window while it is open (it moves when MenuBarAgent places the item). WP10 owns `Panel/` (glass
// container, keyboard focus rules, `panelIn` / `panelOut`, 70 % height cap).
import AppKit
import OverbrightCore
import OverbrightDesign
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Owns the panel window.
final class PanelController {
    /// The panel's width (DESIGN.md §5.1).
    static let width: CGFloat = 320

    private let services: OverbrightServices
    private var panel: OverbrightPanel?
    private var outsideClickMonitor: Any?
    /// Observers of the anchor's window while the panel is open.
    private var anchorObservers: [any NSObjectProtocol] = []

    /// A controller for the app's services. Constructing it opens nothing.
    init(services: OverbrightServices) { self.services = services }

    /// Whether the panel is on screen.
    var isShown: Bool { panel?.isVisible == true }

    /// Opens the panel under `anchor` (the status button), or closes it when it is open.
    func toggle(from anchor: NSView?) {
        if isShown { close() } else { show(from: anchor) }
    }

    /// Opens the panel under `anchor`; without an anchor (the icon is hidden) at the top centre of the main screen;
    /// under an anchor that is not placed yet at the top-right of the main screen, until the anchor moves.
    func show(from anchor: NSView?) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place(panel, under: anchor)
        panel.orderFrontRegardless()
        installOutsideClickMonitor()
        follow(anchor)
    }

    /// Closes the panel.
    func close() {
        panel?.orderOut(nil)
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        stopFollowingAnchor()
    }

    // MARK: Private

    private func makePanel() -> OverbrightPanel {
        let panel = OverbrightPanel(frame: CGRect(x: 0, y: 0, width: Self.width, height: 120))
        let root = PlaceholderPanelView(services: services, onQuit: { NSApp.terminate(nil) })
            .overbrightThemeRoot()
        let hosting = PanelHostingView(rootView: AnyView(root))
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Radius.panel
        background.layer?.masksToBounds = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        panel.onCancel = { [weak self] in self?.close() }
        return panel
    }

    /// Sets `panel`'s frame for `anchor` (an anchor without a window counts as not placed).
    private func place(_ panel: OverbrightPanel, under anchor: NSView?) {
        guard let content = panel.contentView else { return }
        let size = CGSize(width: Self.width, height: content.fittingSize.height)
        let anchorFrame = anchor.map { $0.window?.frame ?? .zero }
        let screens = PanelPlacement.currentScreens
        let frame = PanelPlacement.frame(for: size, anchor: anchorFrame, screens: screens,
                                         main: PanelPlacement.currentMainScreen)
        let placed = anchorFrame.map { PanelPlacement.isPlaced($0, in: screens) }
        let origin = "\(frame.minX),\(frame.minY)"
        log.info("panel at \(origin, privacy: .public) under \(String(describing: anchorFrame), privacy: .public), anchor placed: \(String(describing: placed), privacy: .public)")
        panel.setFrame(frame, display: true)
    }

    /// Re-places the open panel whenever the anchor's window moves or changes screen.
    private func follow(_ anchor: NSView?) {
        stopFollowingAnchor()
        guard let window = anchor?.window else { return }
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didChangeScreenNotification] {
            let observer = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak anchor] _ in
                MainActor.assumeIsolated {                                               // queue: .main
                    guard let self, let panel = self.panel, panel.isVisible else { return }
                    self.place(panel, under: anchor)
                }
            }
            anchorObservers.append(observer)
        }
    }

    private func stopFollowingAnchor() {
        for observer in anchorObservers { NotificationCenter.default.removeObserver(observer) }
        anchorObservers = []
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // Clicks in other apps (our own status item toggles through its button).
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }
}

/// A hosting view that takes the first click (a non-activating panel would otherwise eat it).
private final class PanelHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
