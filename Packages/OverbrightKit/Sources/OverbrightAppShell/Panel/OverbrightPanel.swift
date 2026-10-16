// OverbrightAppShell/Panel/OverbrightPanel.swift — the panel's window: a borderless non-activating `NSPanel`.
// ARCHITECTURE.md §7.6; DESIGN.md §5.1, §5.12 (⌘, Settings, ⌘Q Quit, ⌘W and Esc close). Cranny's `NotchPanel`
// patterns (the owner's MIT code, R1 gotchas): the `.nonactivatingPanel` style at init, `isFloatingPanel` before
// `level`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded`, a `canBecomeKey` override. Seeded by WP0a; WP10 owns
// `Panel/`.
import AppKit
import SwiftUI

/// The panel window. Esc and ⌘W close it through `onCancel`; ⌘, and ⌘Q go to `onCommand`.
final class OverbrightPanel: NSPanel {
    /// The panel's own key commands.
    enum Command: Equatable { case close, settings, quit }

    /// Esc that nothing in the panel handled.
    var onCancel: (() -> Void)?
    /// ⌘W, ⌘, and ⌘Q.
    var onCommand: ((Command) -> Void)?

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
        becomesKeyOnlyIfNeeded = true             // a click into the content makes it key (PanelHostingView)
        isExcludedFromWindowsMenu = true
        animationBehavior = .none                 // panelIn / panelOut are ours (PanelController)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { super.cancelOperation(sender) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let command = Self.command(for: event), let onCommand {
            onCommand(command)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// The panel command of a key event: ⌘W, ⌘, or ⌘Q with no other modifier.
    static func command(for event: NSEvent) -> Command? {
        guard event.type == .keyDown else { return nil }
        return command(characters: event.charactersIgnoringModifiers,
                       modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    /// The panel command of `characters` with `modifiers`.
    static func command(characters: String?, modifiers: NSEvent.ModifierFlags) -> Command? {
        guard modifiers == .command, let key = characters?.lowercased() else { return nil }
        switch key {
        case "w": return .close
        case ",": return .settings
        case "q": return .quit
        default: return nil
        }
    }
}

/// The panel's hosting view: takes the first click (a non-activating panel would otherwise eat it), makes the panel
/// key when clicked (DESIGN.md §5.1: it takes keyboard focus when the user clicks into it), and reports when its
/// ideal size changes so the controller can re-place the panel.
final class PanelHostingView: NSHostingView<AnyView> {
    /// Called after SwiftUI's ideal size changed.
    var onIdealSizeChange: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIdealSizeChange?()
    }
}
