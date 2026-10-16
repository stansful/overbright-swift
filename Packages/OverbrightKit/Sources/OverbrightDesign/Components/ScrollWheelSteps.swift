// OverbrightDesign/Components/ScrollWheelSteps.swift — scroll-wheel notches over a control. DESIGN.md §5.5 ("scrolling
// adjusts by 1/12 stop per notch"), §5.1 (the card list scrolls behind the slider), §15 (pointer and motor). SwiftUI has
// no scroll-wheel hook on macOS 14, so the slider listens with a local event monitor only while the pointer is over it:
// no work otherwise.
//
// A local monitor sees every scroll event of the app, and a window that is ordered out under the pointer gets no
// mouse-exited event (the panel closes with Esc or ⌘, while the pointer rests on a slider). So the monitor takes an
// event only when it is aimed at the control's own window and lands inside the control's frame there
// (`ScrollWheelAnchor` tells it where that is), and it stops when that window resigns key, closes or is hidden.
//
// Over the control, a trackpad's small deltas add up to notches; the ones that do not make a whole notch yet are taken
// too while the control can still move that way, so the card list behind never scrolls between two steps. A notch
// follows the hand, not the scroll direction setting: rolling the wheel away or pushing two fingers up raises the
// level with natural scrolling on (the macOS default, `isDirectionInvertedFromDevice`) or off. Horizontal scrolling
// follows the layout: right to left (boost end on the left) a swipe to the right lowers the level.
//
// The monitor and the window observers go through `ScrollWheelRegistrations`, which counts them, so a test sees a
// listener that goes away take all of them down.
import AppKit
import SwiftUI

/// Turns scroll-wheel events over one control into whole notches while installed (positive: up, or toward the
/// layout's trailing end, as the hand moved).
@MainActor final class ScrollWheelSteps {
    /// What the control does with scrolling.
    struct Target {
        /// The control's layout direction (horizontal scrolling is mirrored right to left).
        var direction: LayoutDirection
        /// Whether one notch in this direction (+1 or −1) would still move the control.
        var canMove: @MainActor (Int) -> Bool
        /// Moves the control by whole notches; returns whether it moved (then the event is consumed).
        var step: @MainActor (Int) -> Bool
    }

    /// Points of precise (trackpad) scrolling that make one notch.
    static let pointsPerNotch: CGFloat = 12

    /// The view that covers the control in its window; nil while the control is not in a window.
    private(set) weak var anchor: NSView?
    private let registrations: ScrollWheelRegistrations
    private var monitor: Any?
    private var target: Target?
    private var windowObservers: [any NSObjectProtocol] = []
    private var accumulated: CGFloat = 0

    /// Whether the monitor is installed.
    var isListening: Bool { monitor != nil }

    /// A listener whose monitor and window observers go through `registrations`.
    init(registrations: ScrollWheelRegistrations = .system) {
        self.registrations = registrations
    }

    /// Starts listening (or keeps listening with a new target). Events elsewhere always pass through.
    func start(_ target: Target) {
        self.target = target
        guard monitor == nil else { return }
        // Local monitors run on the main thread, inside the app's event dispatch.
        monitor = registrations.addMonitor { [weak self] event in
            guard let self else { return event }
            return self.handle(event, in: event.window, at: event.locationInWindow)
        }
    }

    /// Replaces the target of a listener that is running (the control drew again); nothing while stopped.
    func update(_ target: Target) {
        guard monitor != nil else { return }
        self.target = target
    }

    /// Stops listening.
    func stop() {
        if let monitor { registrations.removeMonitor(monitor) }
        monitor = nil
        target = nil
        accumulated = 0
    }

    /// The control's view moved to a window (or out of one, `view` nil or windowless): events are matched against
    /// it from now on, and that window's resign-key, close and hide end the listening.
    func attach(_ view: NSView?) {
        removeWindowObservers()
        anchor = view
        guard let window = view?.window else {
            stop()
            return
        }
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            windowObservers.append(registrations.observe(name, of: window) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }                                // queue: .main
            })
        }
        windowObservers.append(registrations.observe(NSWindow.didChangeOcclusionStateNotification, of: window) {
            [weak self, weak window] _ in
            MainActor.assumeIsolated {                                                   // queue: .main
                guard let window, !window.occlusionState.contains(.visible) else { return }
                self?.stop()
            }
        })
    }

    /// A listener that goes away while it listens takes its monitor and its window observers with it.
    isolated deinit {
        if let monitor { registrations.removeMonitor(monitor) }
        removeWindowObservers()
    }

    /// The monitor's decision for `event`, aimed at `window` at `point` (window coordinates): nil when the control
    /// took it, else the event, untouched.
    func handle(_ event: NSEvent, in window: NSWindow?, at point: NSPoint) -> NSEvent? {
        guard let target, accepts(window, at: point) else { return event }
        let delta = delta(of: event, direction: target.direction)
        guard delta != 0 else { return event }
        guard event.hasPreciseScrollingDeltas else { return target.step(delta > 0 ? 1 : -1) ? nil : event }
        let notches = notches(adding: delta)
        if notches != 0 { return target.step(notches) ? nil : event }
        // Part of a notch: the control's while it can still move that way, the list's once it cannot.
        return target.canMove(delta > 0 ? 1 : -1) ? nil : event
    }

    /// Whether a scroll aimed at `window` at `point` (window coordinates) is over the control: the control's own
    /// window, inside its frame there.
    func accepts(_ window: NSWindow?, at point: NSPoint) -> Bool {
        guard let anchor, let window, anchor.window === window else { return false }
        return anchor.bounds.contains(anchor.convert(point, from: nil))
    }

    /// The scroll of `event` along the control, as the hand moved (`delta(dx:dy:invertedFromDevice:direction:)`).
    func delta(of event: NSEvent, direction: LayoutDirection) -> CGFloat {
        Self.delta(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY,
                   invertedFromDevice: event.isDirectionInvertedFromDevice, direction: direction)
    }

    /// A scroll's motion along the control, positive up (the wheel rolled away, two fingers pushed up) or toward the
    /// trailing end of `direction`: the deltas turned back into the hand's motion first, whatever the scroll direction
    /// setting (natural scrolling inverts them, `invertedFromDevice`; AppKit's positive x is a scroll to the left),
    /// then the larger axis, horizontal motion mirrored right to left.
    nonisolated static func delta(dx: CGFloat, dy: CGFloat, invertedFromDevice: Bool,
                                  direction: LayoutDirection) -> CGFloat {
        let up = invertedFromDevice ? -dy : dy
        let right = invertedFromDevice ? dx : -dx
        return abs(dy) >= abs(dx) ? up : direction.alongLayout(right)
    }

    /// The whole notches after `delta` more points of precise scrolling (one per 12 points); a turn the other way
    /// drops what was left of the last notch.
    func notches(adding delta: CGFloat) -> Int {
        if accumulated != 0, (accumulated > 0) != (delta > 0) { accumulated = 0 }
        accumulated += delta
        let whole = Int(accumulated / Self.pointsPerNotch)
        accumulated -= CGFloat(whole) * Self.pointsPerNotch
        return whole
    }

    private func removeWindowObservers() {
        for observer in windowObservers { registrations.removeObserver(observer) }
        windowObservers = []
    }
}
