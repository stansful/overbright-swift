// OverbrightAppShell/Panel/PanelController.swift — opens and closes the panel under the status item.
// ARCHITECTURE.md §7.6, §10.0; DESIGN.md §5.1 (320 pt wide, up to 70 % of the screen's visible height, closes on an
// outside click, Esc, ⌘W or a second click; keyboard focus only when opened by keyboard or VoiceOver), §2.4 (glass),
// §3.1 (`panelIn` / `panelOut`), §3.2 (Reduce Motion: cross-fade only); D13. Seeded by WP0a: `init(services:)` and
// `toggle(from:)` are fixed; anchored to the status button's window frame (never `NSStatusBar.system.thickness`),
// with `PanelPlacement` keeping it on screen while the button is not placed yet and following the button's window.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Owns the panel window.
final class PanelController {
    /// The panel's width (DESIGN.md §5.1).
    static let width: CGFloat = PanelLayout.width
    /// The downward settle of `panelIn` (DESIGN.md §3.1).
    static let settleDistance: CGFloat = 4

    private let services: OverbrightServices
    private var panel: OverbrightPanel?
    private var hosting: PanelHostingView?
    private weak var anchor: NSView?
    private var monitors: [Any] = []
    /// Observers of the anchor's window while the panel is open.
    private var anchorObservers: [any NSObjectProtocol] = []
    private var isClosing = false

    /// A controller for the app's services. Constructing it opens nothing.
    init(services: OverbrightServices) { self.services = services }

    /// Whether the panel is on screen.
    var isShown: Bool { panel?.isVisible == true && !isClosing }

    /// Opens the panel under `anchor` (the status button), or closes it when it is open.
    func toggle(from anchor: NSView?) {
        if isShown { close() } else { show(from: anchor) }
    }

    /// Opens the panel under `anchor`; without an anchor (the icon is hidden) at the top centre of the main screen;
    /// under an anchor that is not placed yet at the top-right of the main screen, until the anchor moves. The panel
    /// takes keyboard focus when the current event is not a mouse click (keyboard, VoiceOver) or VoiceOver runs.
    func show(from anchor: NSView?) {
        let takesFocus = ClickRouting.isKeyboardOrAccessibility(NSApp.currentEvent)
            || NSWorkspace.shared.isVoiceOverEnabled
        show(from: anchor, takingFocus: takesFocus)
    }

    /// Opens the panel, with keyboard focus on its master switch when `takingFocus`.
    func show(from anchor: NSView?, takingFocus: Bool) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        self.anchor = anchor
        isClosing = false
        install(content(takingFocus: takingFocus), in: panel)
        let frame = place(panel, under: anchor)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.setFrame(reduceMotion ? frame : frame.offsetBy(dx: 0, dy: Self.settleDistance), display: false)
        }
        if takingFocus { panel.makeKeyAndOrderFront(nil) } else { panel.orderFrontRegardless() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = OverbrightMotion.Kind.panelIn.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
        installMonitors()
        follow(anchor)
    }

    /// Closes the panel (`panelOut`: a fade).
    func close() {
        guard let panel, panel.isVisible, !isClosing else { return }
        isClosing = true
        removeMonitors()
        stopFollowingAnchor()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = OverbrightMotion.Kind.panelOut.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {                                   // AppKit runs completions on the main thread
                guard let self, self.isClosing else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                self.isClosing = false
            }
        })
    }

    // MARK: Content

    private func makePanel() -> OverbrightPanel {
        let panel = OverbrightPanel(frame: CGRect(x: 0, y: 0, width: Self.width, height: 120))
        panel.onCancel = { [weak self] in self?.close() }
        panel.onCommand = { [weak self] command in self?.perform(command) }
        return panel
    }

    /// The SwiftUI content (a fresh view per opening: focus and the "Why?" row start over).
    private func content(takingFocus: Bool) -> AnyView {
        AnyView(PanelView(services: services, symbol: { Image(nsImage: StatusSymbolImage.image(for: $0)) },
                          takesFocus: takingFocus, close: { [weak self] in self?.close() })
            .overbrightThemeRoot())
    }

    private func install(_ root: AnyView, in panel: OverbrightPanel) {
        let hosting = PanelHostingView(rootView: root)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.setContentHuggingPriority(.defaultLow, for: .vertical)
        hosting.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        hosting.onIdealSizeChange = { [weak self] in
            Task { @MainActor in self?.replace() }                       // after SwiftUI finished this update
        }
        self.hosting = hosting
        panel.contentView = PanelContainer.make(around: hosting, material: PanelContainer.currentMaterial)
    }

    /// Re-places the open panel (its content's ideal height changed).
    private func replace() {
        guard let panel, panel.isVisible, !isClosing else { return }
        panel.setFrame(frame(under: anchor), display: true)
    }

    /// Sets `panel`'s frame for `anchor` (an anchor without a window counts as not placed); returns it.
    @discardableResult
    private func place(_ panel: OverbrightPanel, under anchor: NSView?) -> CGRect {
        let frame = frame(under: anchor)
        let anchorFrame = anchor.map { $0.window?.frame ?? .zero }
        let placed = anchorFrame.map { PanelPlacement.isPlaced($0, in: PanelPlacement.currentScreens) }
        let origin = "\(frame.minX),\(frame.minY)"
        log.info("panel at \(origin, privacy: .public) under \(String(describing: anchorFrame), privacy: .public), anchor placed: \(String(describing: placed), privacy: .public)")
        panel.setFrame(frame, display: true)
        return frame
    }

    private func frame(under anchor: NSView?) -> CGRect {
        let ideal = hosting?.intrinsicContentSize.height ?? 120
        let anchorFrame = anchor.map { $0.window?.frame ?? .zero }
        let screens = PanelPlacement.currentScreens
        let main = PanelPlacement.currentMainScreen
        let height = PanelPlacement.height(ideal: ideal > 0 ? ideal : 120, anchor: anchorFrame, screens: screens,
                                           main: main)
        return PanelPlacement.frame(for: CGSize(width: Self.width, height: height), anchor: anchorFrame,
                                    screens: screens, main: main)
    }

    private func perform(_ command: OverbrightPanel.Command) {
        switch command {
        case .close:
            close()
        case .settings:
            close()
            services.app?.openSettings(nil)
        case .quit:
            close()
            services.app?.quit()
        }
    }

    // MARK: Following the anchor, outside clicks

    /// Re-places the open panel whenever the anchor's window moves or changes screen.
    private func follow(_ anchor: NSView?) {
        stopFollowingAnchor()
        guard let window = anchor?.window else { return }
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didChangeScreenNotification] {
            let observer = center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.replace() }                                   // queue: .main
            }
            anchorObservers.append(observer)
        }
    }

    private func stopFollowingAnchor() {
        for observer in anchorObservers { NotificationCenter.default.removeObserver(observer) }
        anchorObservers = []
    }

    /// Closes on a click in another app, or in another window of ours (the status button toggles by itself).
    private func installMonitors() {
        guard monitors.isEmpty else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown],
                                                          handler: { [weak self] _ in self?.close() }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown],
                                                        handler: { [weak self] event in
            guard let self else { return event }
            // Popovers and menus of the panel itself are its child windows (or float above it): they keep it open.
            if let window = event.window, window !== self.panel, window !== self.anchor?.window,
               window.parent !== self.panel,
               !(window is NSPanel && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue) {
                self.close()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
    }
}

private extension OverbrightMotion.Kind {
    /// The duration of the panel's motion kinds (DESIGN.md §3.1).
    var duration: TimeInterval {
        switch self {
        case .panelIn: 0.18
        case .panelOut: 0.12
        default: 0.2
        }
    }
}
