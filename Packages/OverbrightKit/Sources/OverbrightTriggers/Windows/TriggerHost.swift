// OverbrightTriggers/Windows/TriggerHost.swift — owns the one window of a trigger or overlay: layer hosting, occlusion
// reporting, screen-change reporting, re-placement and teardown. ARCHITECTURE.md §3.6 (`TriggerHandle`,
// `OverlayHandle`), §4.3 ("onScreenChange" row), §4.7, §7.1 ("Trigger occlusion, screen change"), §7.6.
// Thread: main. Both notifications are observed with `queue: .main`, so their blocks run on the main queue
// (`MainActor.assumeIsolated` is used only there).
import AppKit
import CoreGraphics
import OverbrightCore
import QuartzCore

/// One trigger or overlay window on one display.
final class TriggerHost {
    /// Which frame the window takes on its screen.
    enum Shape: Hashable {
        /// The 1 pt trigger at `placement`, `edgePoints` on a side.
        case trigger(placement: TriggerPlacement, edgePoints: Double)
        /// The Compatibility overlay: the whole screen, menu bar included.
        case fullScreen
    }

    /// The display the window belongs to.
    let display: DisplayRef
    /// The frame rule.
    let shape: Shape
    /// The window once prepared; nil before and after.
    private(set) var window: NSPanel?
    /// Whether `orderIn()` ran since the window was prepared.
    private(set) var isOrderedIn = false
    /// The last occlusion AppKit reported (false until it reports one).
    private(set) var isOccluded = false
    /// Called when the occlusion state changes (true: hidden, e.g. by the lock shield).
    var onOcclusionChange: ((Bool) -> Void)?
    /// Called when AppKit moves the window to another screen, with that screen's display (nil: none).
    var onScreenChange: ((CGDirectDisplayID?) -> Void)?

    private let screens: any TriggerScreens
    private let presenter: any WindowPresenting
    private var observers: [any NSObjectProtocol] = []

    init(display: DisplayRef, shape: Shape, screens: any TriggerScreens, presenter: any WindowPresenting) {
        self.display = display
        self.shape = shape
        self.screens = screens
        self.presenter = presenter
    }

    isolated deinit { tearDown() }

    /// Whether the window exists (prepared and not torn down).
    var hasWindow: Bool { window != nil }

    /// The frame the window should have now; nil when the display has no screen.
    func targetFrame() -> CGRect? {
        guard let screen = screens.geometry(of: display.id) else { return nil }
        switch shape {
        case .trigger(let placement, let edgePoints):
            return TriggerGeometry.triggerFrame(on: screen, placement: placement, edgePoints: edgePoints)
        case .fullScreen:
            return TriggerGeometry.overlayFrame(on: screen)
        }
    }

    /// Builds the window around `layer` (a layer-hosting view: the layer is assigned before `wantsLayer`) and starts
    /// observing occlusion and screen changes. Does not order it in. Replaces a window prepared earlier.
    func prepare(layer: CALayer, blend: TriggerBlend) throws {
        guard let frame = targetFrame() else { throw TriggerError.displayGone }
        tearDown()
        let panel = WindowRecipes.makePanel(frame: frame)
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.layer = layer
        view.wantsLayer = true
        view.setAccessibilityElement(false)
        layer.frame = view.bounds
        if blend == .softLight { layer.compositingFilter = "softLightBlendMode" }
        panel.contentView = view
        window = panel
        observe(panel)
    }

    /// Puts the prepared window on screen.
    func orderIn() {
        guard let window else { return }
        presenter.orderIn(window)
        isOrderedIn = true
    }

    /// `prepare(layer:blend:)`, then `orderIn()`.
    func show(layer: CALayer, blend: TriggerBlend) throws {
        try prepare(layer: layer, blend: blend)
        orderIn()
    }

    /// Follows the screen's geometry after a screen-parameters change (resolution, arrangement, notch areas). Leaves
    /// the window where it is when the display has no screen (the engine removes it).
    func reposition() {
        guard let window, let frame = targetFrame() else { return }
        if window.frame != frame { window.setFrame(frame, display: false) }
        if let layer = window.contentView?.layer { layer.frame = NSRect(origin: .zero, size: frame.size) }
    }

    /// Orders the window out, stops observing and releases it. Safe to call more than once.
    func tearDown() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        if let window {
            presenter.orderOut(window)
            window.contentView = nil
            window.close()
        }
        window = nil
        isOrderedIn = false
        isOccluded = false
    }

    // MARK: Observation

    private func observe(_ panel: NSPanel) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel,
                                            queue: .main) { [weak self] _ in
            // Delivered on the main queue (`queue: .main`), so the main actor is current.
            MainActor.assumeIsolated { self?.occlusionChanged() }
        })
        observers.append(center.addObserver(forName: NSWindow.didChangeScreenNotification, object: panel,
                                            queue: .main) { [weak self] _ in
            // Delivered on the main queue (`queue: .main`), so the main actor is current.
            MainActor.assumeIsolated { self?.screenChanged() }
        })
    }

    private func occlusionChanged() {
        guard let window else { return }
        let occluded = !window.occlusionState.contains(.visible)
        guard occluded != isOccluded else { return }
        isOccluded = occluded
        onOcclusionChange?(occluded)
    }

    private func screenChanged() {
        guard let window else { return }
        onScreenChange?(screens.display(of: window))
    }
}
