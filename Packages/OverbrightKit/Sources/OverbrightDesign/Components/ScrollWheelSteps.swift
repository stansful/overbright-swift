// OverbrightDesign/Components/ScrollWheelSteps.swift — scroll-wheel notches over a control. DESIGN.md §5.5 ("scrolling
// adjusts by 1/12 stop per notch"), §15 (pointer and motor). SwiftUI has no scroll-wheel hook on macOS 14, so the slider
// listens with a local event monitor only while the pointer is over it: no work otherwise.
//
// A local monitor sees every scroll event of the app, and a window that is ordered out under the pointer gets no
// mouse-exited event (the panel closes with Esc or ⌘, while the pointer rests on a slider). So the monitor takes an
// event only when it is aimed at the control's own window and lands inside the control's frame there
// (`ScrollWheelAnchor` tells it where that is), and it stops when that window resigns key, closes or is hidden.
import AppKit

/// Turns scroll-wheel events over one control into whole notches while installed (positive: up or right).
@MainActor final class ScrollWheelSteps {
    /// Points of precise (trackpad) scrolling that make one notch.
    static let pointsPerNotch: CGFloat = 12

    /// The view that covers the control in its window; nil while the control is not in a window.
    private(set) weak var anchor: NSView?
    private var monitor: Any?
    private var onNotches: (@MainActor (Int) -> Bool)?
    private var windowObservers: [any NSObjectProtocol] = []
    private var accumulated: CGFloat = 0

    /// Whether the monitor is installed.
    var isListening: Bool { monitor != nil }

    /// Starts listening (or keeps listening with a new handler); `onNotches` gets the notches of each event over the
    /// control and returns whether it used them (then the event is consumed, so a scroll view behind does not scroll
    /// as well). Events elsewhere always pass through.
    func start(_ onNotches: @escaping @MainActor (Int) -> Bool) {
        self.onNotches = onNotches
        guard monitor == nil else { return }
        // Local monitors run on the main thread, inside the app's event dispatch.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event, in: event.window, at: event.locationInWindow)
        }
    }

    /// Stops listening.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onNotches = nil
        accumulated = 0
    }

    /// The control's view moved to a window (or out of one, `view` nil or windowless): events are matched against
    /// it from now on, and that window's resign-key, close and hide end the listening.
    func attach(_ view: NSView?) {
        for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
        windowObservers = []
        anchor = view
        guard let window = view?.window else {
            stop()
            return
        }
        let center = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            windowObservers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }                                // queue: .main
            })
        }
        windowObservers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window,
                                                  queue: .main) { [weak self, weak window] _ in
            MainActor.assumeIsolated {                                                   // queue: .main
                guard let window, !window.occlusionState.contains(.visible) else { return }
                self?.stop()
            }
        })
    }

    /// The monitor's decision for `event`, aimed at `window` at `point` (window coordinates): nil when the control
    /// used it, else the event, untouched.
    func handle(_ event: NSEvent, in window: NSWindow?, at point: NSPoint) -> NSEvent? {
        guard let onNotches, accepts(window, at: point) else { return event }
        let notches = notches(of: event)
        guard notches != 0 else { return event }
        return onNotches(notches) ? nil : event
    }

    /// Whether a scroll aimed at `window` at `point` (window coordinates) is over the control: the control's own
    /// window, inside its frame there.
    func accepts(_ window: NSWindow?, at point: NSPoint) -> Bool {
        guard let anchor, let window, anchor.window === window else { return false }
        return anchor.bounds.contains(anchor.convert(point, from: nil))
    }

    /// The whole notches in `event`: one per line-based wheel event, one per 12 points of precise scrolling.
    func notches(of event: NSEvent) -> Int {
        let dy = event.scrollingDeltaY, dx = event.scrollingDeltaX
        let delta = abs(dy) >= abs(dx) ? dy : dx
        guard delta != 0 else { return 0 }
        guard event.hasPreciseScrollingDeltas else { return delta > 0 ? 1 : -1 }
        accumulated += delta
        let whole = Int(accumulated / Self.pointsPerNotch)
        accumulated -= CGFloat(whole) * Self.pointsPerNotch
        return whole
    }
}
