// OverbrightAppShell/HUD/HUDWindow.swift — the window of the HUD and of the Keep-this-level prompt. ARCHITECTURE.md
// §7.6: a non-activating `NSPanel` at `.statusBar` on every Space and over full-screen apps, `sharingType = .none`
// (left out of screenshots where macOS honours it); the HUD ignores the mouse and never becomes key, the prompt can
// become key (Return = Keep, Esc = Go Back). DESIGN.md §6. Cranny's window gotchas: the style at init, the level after
// `isFloatingPanel`, `ignoresMouseEvents` set explicitly.
import AppKit

/// A HUD-place window.
final class HUDWindow: NSPanel {
    /// The window takes clicks and can become key (the prompt).
    let isInteractive: Bool
    /// Esc (the prompt: Go Back).
    var onCancel: (() -> Void)?

    /// A HUD (`interactive` false) or the prompt (`true`) with `frame`.
    init(frame: CGRect, interactive: Bool) {
        isInteractive = interactive
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        sharingType = .none
        ignoresMouseEvents = !interactive
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { isInteractive }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { super.cancelOperation(sender) }
    }
}
