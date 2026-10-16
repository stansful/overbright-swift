// OverbrightDesign/Components/ScrollWheelSteps.swift — scroll-wheel notches over a control. DESIGN.md §5.5 ("scrolling
// adjusts by 1/12 stop per notch"), §15 (pointer and motor). SwiftUI has no scroll-wheel hook on macOS 14, so the slider
// listens with a local event monitor only while the pointer is over it: no work otherwise.
import AppKit

/// Turns scroll-wheel events into whole notches while installed (positive: up or right).
@MainActor final class ScrollWheelSteps {
    /// Points of precise (trackpad) scrolling that make one notch.
    static let pointsPerNotch: CGFloat = 12

    private var monitor: Any?
    private var accumulated: CGFloat = 0

    /// Starts listening; `onNotches` gets the notches of each event and returns whether it used them (then the event
    /// is consumed, so a scroll view behind does not scroll as well).
    func start(_ onNotches: @escaping @MainActor (Int) -> Bool) {
        stop()
        // Local monitors run on the main thread, inside the app's event dispatch.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            let notches = self.notches(of: event)
            guard notches != 0 else { return event }
            return onNotches(notches) ? nil : event
        }
    }

    /// Stops listening.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        accumulated = 0
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
