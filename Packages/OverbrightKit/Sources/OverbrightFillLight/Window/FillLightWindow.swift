// OverbrightFillLight/Window/FillLightWindow.swift — the frame window on one display. ARCHITECTURE.md §7.6 (recipe,
// full frame), §7.1 (screen change → reported, the controller removes it; occlusion → visible re-presents), D12;
// DESIGN.md §11 (the top edge below the menu bar).
//
// Thread: main. The window's notifications are observed with `queue: .main`, so their blocks run on the main thread
// and assume the main actor (§8.1 rule 2). The Metal path presents only while the window is visible, and its
// first-present retry is a stored task on the injected `TimeSource`, bounded and cancelled on removal (§8.1 rule 5).
import AppKit
import CoreGraphics
import OverbrightCore
import QuartzCore

/// One display's frame window: `FillLightWindowRecipe` + `FillLightLayers`, laid out by `FrameGeometry` from the
/// display's current `NSScreen`.
final class FillLightWindow: FillLightSurface {
    /// The Metal path retries a present that found no drawable every 250 ms, at most 8 times (2 s), while visible.
    static let presentRetryInterval: Duration = .milliseconds(250)
    /// See `presentRetryInterval`.
    static let presentRetryLimit = 8

    let display: DisplayRef
    var rendering: FillLightRendering { layers.rendering }
    var onScreenChange: (@MainActor (CGDirectDisplayID?) -> Void)?

    private let panel: NSPanel
    private let layers: FillLightLayers
    private let screenNow: @MainActor () -> NSScreen?
    private let displayIDOf: @MainActor (NSScreen?) -> CGDirectDisplayID?
    private let time: any TimeSource
    private let onOrderChange: @MainActor (Bool) -> Void
    private var style: FillLightStyle?
    private var isOrderedIn = false
    private var isRemoved = false
    private var observers: [any NSObjectProtocol] = []
    private var retry: Task<Void, Never>?

    /// A window for `display` on `screen`, not ordered in. `screenNow` finds the display's screen again at every layout
    /// (NSScreen objects are re-fetched after parameter changes); `displayIDOf` names the display of the screen AppKit
    /// moved the window to (the `--qa-simulate` stand-in maps its fallback screen to `display`); `onOrderChange(true/
    /// false)` reports ordering in and out.
    init(display: DisplayRef, screen: NSScreen, screenNow: @escaping @MainActor () -> NSScreen?,
         displayIDOf: @escaping @MainActor (NSScreen?) -> CGDirectDisplayID?, rendering: FillLightRendering,
         time: any TimeSource, onOrderChange: @escaping @MainActor (Bool) -> Void) {
        self.display = display
        self.screenNow = screenNow
        self.displayIDOf = displayIDOf
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
        guard !isRemoved else { return }
        self.style = style
        guard isOrderedIn else {
            orderIn()
            return
        }
        if !layout(presentsDrawable: isVisible) { retryPresent() }
    }

    func refresh() {
        guard isOrderedIn, style != nil else { return }
        if !layout(presentsDrawable: isVisible) { retryPresent() }   // the layout re-presents the Metal drawable too
    }

    func remove() {
        isRemoved = true
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

    // MARK: Ordering in

    /// Lays the frame out, orders the window in and presents the first drawable. Counted and observed before
    /// `orderFrontRegardless()`: AppKit may post `didChangeScreen` while ordering the panel in, and the controller
    /// then calls `remove()` inside this call, which balances the count and leaves nothing to present.
    private func orderIn() {
        _ = layout(presentsDrawable: false)   // shape and colour in place before the window shows
        isOrderedIn = true
        onOrderChange(true)
        observe()
        panel.orderFrontRegardless()   // an agent app is never active
        guard !isRemoved else { return }
        // The Metal path's first drawable, now that the window is in the render tree. A fresh layer has a free
        // drawable, so this does not wait even before the occlusion state reports the window visible.
        if rendering == .metalClear, !layers.showColor() { retryPresent() }
    }

    // MARK: Layout

    /// Whether the window shows on screen now (the Metal path presents only then).
    private var isVisible: Bool { panel.occlusionState.contains(.visible) }

    /// Places the window over the display's current frame and lays the layers out. False only when the Metal path
    /// tried and found no drawable.
    private func layout(presentsDrawable: Bool) -> Bool {
        guard let style, let screen = screenNow() else { return true }
        let frame = screen.frame
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        let band = FrameGeometry.menuBarBand(reported: frame.maxY - screen.visibleFrame.maxY,
                                             showsMenuBar: showsMenuBar(screen),
                                             barHeight: NSApp?.mainMenu?.menuBarHeight ?? 0)
        let geometry = FrameGeometry(displaySize: frame.size, menuBarHeight: band,
                                     safeAreaTop: screen.safeAreaInsets.top, width: style.width,
                                     reachesTop: style.reachesTop)
        return layers.apply(style, geometry: geometry, scale: screen.backingScaleFactor,
                            presentsDrawable: presentsDrawable)
    }

    /// Every display shows a menu bar when displays have separate Spaces; otherwise only the first screen does.
    private func showsMenuBar(_ screen: NSScreen) -> Bool {
        guard !NSScreen.screensHaveSeparateSpaces else { return true }
        guard let first = NSScreen.screens.first else { return false }
        return ScreenLookup.displayID(of: first) == ScreenLookup.displayID(of: screen)
    }

    private func retryPresent() {
        guard rendering == .metalClear, retry == nil, !isRemoved else { return }
        retry = Task { [weak self, time] in
            for _ in 0..<Self.presentRetryLimit {
                do { try await time.sleep(for: Self.presentRetryInterval) } catch { return }
                guard let self, !Task.isCancelled, !self.isRemoved else { return }
                // Hidden: stop; `occlusionChanged` presents once the window is visible again.
                guard self.isVisible, !self.layers.showColor() else { break }
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

    /// Reports the display of the screen AppKit moved the window to (`didChangeScreenNotification`).
    func screenChanged() {
        guard !isRemoved else { return }
        onScreenChange?(displayIDOf(panel.screen))
    }

    private func occlusionChanged() {
        // A drawable may have been purged while hidden; a colour layer needs nothing.
        guard rendering == .metalClear, !isRemoved, isVisible else { return }
        if !layers.showColor() { retryPresent() }
    }
}
