// OverbrightFillLight/Window/FillLightWindow.swift — the frame window on one display. ARCHITECTURE.md §7.6 (recipe,
// full frame), §7.1 (screen change → reported, the controller removes it; occlusion → visible re-presents), D12;
// DESIGN.md §11.
//
// Thread: main. The window's notifications are observed with `queue: .main`, so their blocks run on the main thread
// and assume the main actor (§8.1 rule 2). The Metal path's first-present retry is a stored task on the injected
// `TimeSource`, bounded and cancelled on removal (§8.1 rule 5).
import AppKit
import CoreGraphics
import OverbrightCore
import QuartzCore

/// One display's frame window: `FillLightWindowRecipe` + `FillLightLayers`, laid out by `FrameGeometry` from the
/// display's current `NSScreen`.
final class FillLightWindow: FillLightSurface {
    /// The Metal path retries its first present every 50 ms for up to 2 s (the window may not be in the render tree yet).
    static let presentRetryInterval: Duration = .milliseconds(50)
    /// See `presentRetryInterval`.
    static let presentRetryLimit = 40

    let display: DisplayRef
    var rendering: FillLightRendering { layers.rendering }
    var onScreenChange: (@MainActor (CGDirectDisplayID?) -> Void)?

    private let panel: NSPanel
    private let layers: FillLightLayers
    private let screenNow: @MainActor () -> NSScreen?
    private let time: any TimeSource
    private let onOrderChange: @MainActor (Bool) -> Void
    private var style: FillLightStyle?
    private var isOrderedIn = false
    private var observers: [any NSObjectProtocol] = []
    private var retry: Task<Void, Never>?

    /// A window for `display` on `screen`, not ordered in. `screenNow` finds the display's screen again at every layout
    /// (NSScreen objects are re-fetched after parameter changes); `onOrderChange(true/false)` reports ordering in and out.
    init(display: DisplayRef, screen: NSScreen, screenNow: @escaping @MainActor () -> NSScreen?,
         rendering: FillLightRendering, time: any TimeSource, onOrderChange: @escaping @MainActor (Bool) -> Void) {
        self.display = display
        self.screenNow = screenNow
        self.time = time
        self.onOrderChange = onOrderChange
        layers = FillLightLayers(rendering: rendering, display: display.id)
        panel = FillLightWindowRecipe.makePanel(frame: screen.frame)
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.layer = layers.root   // layer-hosting view: assign the layer first, then turn wantsLayer on
        view.wantsLayer = true
        view.setAccessibilityElement(false)
        panel.contentView = view
    }

    func apply(_ style: FillLightStyle) {
        self.style = style
        var shown = layout()
        if !isOrderedIn {
            isOrderedIn = true
            observe()
            panel.orderFrontRegardless()   // an agent app is never active
            onOrderChange(true)
            if rendering == .metalClear { shown = layers.showColor() }   // now that it is in the render tree
        }
        if !shown { retryPresent() }
    }

    func refresh() {
        guard style != nil else { return }
        let shown = layout()
        if rendering == .metalClear, !(shown && layers.showColor()) { retryPresent() }
    }

    func remove() {
        retry?.cancel()
        retry = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        onScreenChange = nil
        panel.orderOut(nil)
        panel.close()
        if isOrderedIn {
            isOrderedIn = false
            onOrderChange(false)
        }
    }

    // MARK: Layout

    /// Places the window over the display's current frame and lays the layers out. False only when the Metal path
    /// found no drawable.
    private func layout() -> Bool {
        guard let style, let screen = screenNow() else { return true }
        let frame = screen.frame
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        let geometry = FrameGeometry(displaySize: frame.size, menuBarHeight: frame.maxY - screen.visibleFrame.maxY,
                                     safeAreaTop: screen.safeAreaInsets.top, width: style.width,
                                     reachesTop: style.reachesTop)
        return layers.apply(style, geometry: geometry, scale: screen.backingScaleFactor)
    }

    private func retryPresent() {
        guard rendering == .metalClear, retry == nil else { return }
        retry = Task { [weak self, time] in
            for _ in 0..<Self.presentRetryLimit {
                do { try await time.sleep(for: Self.presentRetryInterval) } catch { return }
                guard let self, !Task.isCancelled else { return }
                if self.layers.showColor() { break }
            }
            self?.retry = nil
        }
    }

    // MARK: Notifications (main queue)

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didChangeScreenNotification, object: panel,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenChanged() }   // queue: .main
        })
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.occlusionChanged() }   // queue: .main
        })
    }

    private func screenChanged() {
        onScreenChange?(panel.screen.flatMap(ScreenLookup.displayID(of:)))
    }

    private func occlusionChanged() {
        // A drawable may have been purged while hidden; a colour layer needs nothing.
        guard rendering == .metalClear, panel.occlusionState.contains(.visible) else { return }
        if !layers.showColor() { retryPresent() }
    }
}
