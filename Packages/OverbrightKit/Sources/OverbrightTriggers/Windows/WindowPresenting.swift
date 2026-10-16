// OverbrightTriggers/Windows/WindowPresenting.swift — the only code that orders a trigger or overlay window in.
// ARCHITECTURE.md §7.6, §9.1 ("No test ever orders a window in"), D24. Thread: main.
//
// `SystemWindowPresenter` is the single place in the module that calls `orderFrontRegardless()` (lint test
// `onlyThePresenterOrdersWindowsIn`); tests inject a recording presenter, so a test run never puts a window, and
// therefore never an EDR request, on screen.
import AppKit

/// Orders trigger and overlay windows in and out.
protocol WindowPresenting: AnyObject {
    /// Puts `window` on screen.
    func orderIn(_ window: NSWindow)
    /// Takes `window` off screen.
    func orderOut(_ window: NSWindow)
}

/// The real presenter. An agent app is never active, so windows are ordered in regardless.
final class SystemWindowPresenter: WindowPresenting {
    /// `orderFrontRegardless()`.
    func orderIn(_ window: NSWindow) { window.orderFrontRegardless() }
    /// `orderOut(nil)`.
    func orderOut(_ window: NSWindow) { window.orderOut(nil) }
}
