// OverbrightTriggersTests/Support/TestDoubles.swift — the doubles every Triggers suite uses: fixed screens, a
// presenter that records instead of ordering windows in, and a scripted clear-frame surface. ARCHITECTURE.md §9.1
// ("No test ever orders a window in"), §10.5.
import AppKit
import CoreGraphics
import QuartzCore
@testable import OverbrightTriggers

/// Screens with fixed geometry. Counts lookups, so a test can prove that a call made no display query.
final class FixedScreens: TriggerScreens {
    /// Geometry per display ID (remove an entry to "unplug" it).
    var screens: [CGDirectDisplayID: ScreenGeometry]
    /// What `display(of:)` answers for every window (the screen AppKit moved it to).
    var windowDisplay: CGDirectDisplayID?
    /// Number of `geometry(of:)` calls.
    private(set) var geometryLookups = 0

    init(_ screens: [CGDirectDisplayID: ScreenGeometry], windowDisplay: CGDirectDisplayID? = nil) {
        self.screens = screens
        self.windowDisplay = windowDisplay
    }

    func geometry(of display: CGDirectDisplayID) -> ScreenGeometry? {
        geometryLookups += 1
        return screens[display]
    }

    func display(of window: NSWindow) -> CGDirectDisplayID? { windowDisplay }
}

/// Records order-in and order-out calls; never puts a window on screen.
final class RecordingPresenter: WindowPresenting {
    /// Windows "ordered in", in order.
    private(set) var orderedIn: [NSWindow] = []
    /// Windows ordered out, in order.
    private(set) var orderedOut: [NSWindow] = []

    func orderIn(_ window: NSWindow) { orderedIn.append(window) }
    func orderOut(_ window: NSWindow) { orderedOut.append(window) }
}

/// A clear-frame surface that fails its first presents as scripted and records everything.
final class ScriptedClearSurface: ClearFrameSurface {
    /// A plain layer stands in for the `CAMetalLayer`.
    let layer = CALayer()
    /// The next this-many presents fail (a window not yet in the render tree).
    var failuresBeforeSuccess: Int
    /// Every present always fails.
    var alwaysFails = false
    /// Values of the successful presents, in order.
    private(set) var presentedValues: [Double] = []
    /// Number of present attempts (failed ones included).
    private(set) var attempts = 0
    /// Every `applyTag(_:)` value.
    private(set) var tags: [Double?] = []
    /// `release()` ran.
    private(set) var isReleased = false

    init(failuresBeforeSuccess: Int = 0) { self.failuresBeforeSuccess = failuresBeforeSuccess }

    func presentFrame(_ value: Double) -> Bool {
        attempts += 1
        guard !isReleased, !alwaysFails else { return false }
        if failuresBeforeSuccess > 0 {
            failuresBeforeSuccess -= 1
            return false
        }
        presentedValues.append(value)
        return true
    }

    func applyTag(_ headroom: Double?) { tags.append(headroom) }
    func release() { isReleased = true }
}
