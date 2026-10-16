// OverbrightAppShell/Windows/CalibrationWindow.swift — the calibration window itself (ARCHITECTURE.md §7.6; DESIGN.md
// §9): borderless and full screen on the display under test, so it can become key (for Space, Return and Esc) and
// turns Esc (`cancelOperation`) into the session's immediate return to Standard. Owned by `CalibrationWindowController`.
import AppKit

/// A borderless window that takes keys and reports Esc.
final class CalibrationWindow: NSWindow {
    /// Esc: the controller ends the session at once.
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
