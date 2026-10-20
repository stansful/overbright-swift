// OverbrightTriggers/Windows/SystemWindowPresenter.swift — the only code that orders a trigger window in.
// ARCHITECTURE.md §7.6, §9.1 ("No test ever orders a window in"), D24. Thread: main.
//
// The single place in the module that calls `orderFrontRegardless()` (lint test
// `onlyTheSystemPresenterOrdersAWindowIn`); tests never construct it (`testsNeverReachTheRealPresenterOrScreens`).
import AppKit

/// The real presenter. An agent app is never active, so windows are ordered in regardless.
final class SystemWindowPresenter: WindowPresenting {
    /// `orderFrontRegardless()`.
    func orderIn(_ window: NSWindow) { window.orderFrontRegardless() }
    /// `orderOut(nil)`.
    func orderOut(_ window: NSWindow) { window.orderOut(nil) }
}
