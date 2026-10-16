// OverbrightAppShell/Panel/PanelController.swift — opens and closes the panel under the status item.
// ARCHITECTURE.md §7.6, §10.0; DESIGN.md §5.1. Seeded by WP0a: `init(services:)` and `toggle(from:)` are fixed; the
// WP0a body shows `PlaceholderPanelView` in an `OverbrightPanel`, anchored to the status button's window frame (never
// `NSStatusBar.system.thickness`, which says 22 pt while the bar is 30 pt on macOS 27), closing on an outside click
// or Esc. WP10 owns `Panel/` (glass container, keyboard focus rules, `panelIn` / `panelOut`, 70 % height cap).
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
    /// Distance from the screen edges.
    private static let screenMargin: CGFloat = 8
    /// Gap between the menu bar and the panel.
    private static let gap: CGFloat = 4

    private let services: OverbrightServices
    private var panel: OverbrightPanel?
    private var outsideClickMonitor: Any?

    /// A controller for the app's services. Constructing it opens nothing.
    init(services: OverbrightServices) { self.services = services }

    /// Whether the panel is on screen.
    var isShown: Bool { panel?.isVisible == true }

    /// Opens the panel under `anchor` (the status button), or closes it when it is open.
    func toggle(from anchor: NSView?) {
        if isShown { close() } else { show(from: anchor) }
    }

    /// Opens the panel under `anchor`; without an anchor (the icon is hidden) at the top centre of the main screen.
    func show(from anchor: NSView?) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        guard let content = panel.contentView else { return }
        let size = CGSize(width: Self.width, height: content.fittingSize.height)
        let frame = frame(for: size, anchor: anchor)
        log.info("panel at \(frame.minX, privacy: .public),\(frame.minY, privacy: .public) under \(String(describing: anchor?.window?.frame), privacy: .public)")
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        installOutsideClickMonitor()
    }

    /// Closes the panel.
    func close() {
        panel?.orderOut(nil)
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
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

    private func frame(for size: CGSize, anchor: NSView?) -> CGRect {
        // A status button whose window AppKit has not placed yet is 0 pt high at the origin: not an anchor.
        let anchorFrame = (anchor?.window?.frame).flatMap { $0.height > 0 ? $0 : nil }
        let screen = (anchorFrame == nil ? nil : anchor?.window?.screen) ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let full = screen?.frame ?? visible
        let midX = anchorFrame?.midX ?? visible.midX
        let top = anchorFrame?.minY ?? full.maxY - (full.maxY - visible.maxY)
        let x = min(max(midX - size.width / 2, full.minX + Self.screenMargin), full.maxX - Self.screenMargin - size.width)
        return CGRect(x: x, y: top - Self.gap - size.height, width: size.width, height: size.height)
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
