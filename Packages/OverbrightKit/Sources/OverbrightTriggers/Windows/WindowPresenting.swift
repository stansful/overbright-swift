// OverbrightTriggers/Windows/WindowPresenting.swift — the seam through which trigger and overlay windows reach the
// screen. ARCHITECTURE.md §7.6, §9.1 ("No test ever orders a window in"), D24. Thread: main.
//
// `SystemWindowPresenter` (its own file) is the only implementation that orders a window in; tests inject a recording
// presenter, so a test run never puts a window, and therefore never an EDR request, on screen.
import AppKit

/// Orders trigger and overlay windows in and out.
protocol WindowPresenting: AnyObject {
    /// Puts `window` on screen.
    func orderIn(_ window: NSWindow)
    /// Takes `window` off screen.
    func orderOut(_ window: NSWindow)
}
