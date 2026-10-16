// OverbrightAppShell/Panel/OverbrightPanel.swift — the panel's window: a borderless non-activating `NSPanel`.
// ARCHITECTURE.md §7.6; DESIGN.md §5.1. Cranny's `NotchPanel` patterns (the owner's MIT code, R1 gotchas): the
// `.nonactivatingPanel` style at init, `isFloatingPanel` before `level`, `hidesOnDeactivate = false`,
// `becomesKeyOnlyIfNeeded`, a `canBecomeKey` override. Seeded by WP0a; WP10 owns `Panel/`.
import AppKit

/// The panel window. Esc closes it through `onCancel`.
final class OverbrightPanel: NSPanel {
    /// Esc that nothing in the panel handled.
    var onCancel: (() -> Void)?

    /// A panel with `frame` (in screen coordinates).
    init(frame: CGRect) {
        // .nonactivatingPanel MUST be in the init style mask (Cranny R1 gotcha 4).
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true                    // resets the level: set the level after it (R1 gotcha 1)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { super.cancelOperation(sender) }
    }
}
