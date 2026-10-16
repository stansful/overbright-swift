// OverbrightTriggers/Windows/WindowRecipes.swift — the one window recipe for the 1 pt trigger and the full-screen
// Compatibility overlay. ARCHITECTURE.md §7.5, §7.6 ("Trigger windows"), D4. Thread: main.
//
// Making a panel orders nothing in: only `SystemWindowPresenter` does that, and tests never construct it.
import AppKit

/// The trigger and overlay panel recipe.
enum WindowRecipes {
    /// Above the menu bar, the Dock, pop-up menus and full-screen windows; below the lock-screen shield, so locking
    /// hides the trigger and headroom drops, which the engine wants.
    static let level: NSWindow.Level = .screenSaver

    /// On every Space, unaffected by Mission Control, not in ⌘`, shown over full-screen Spaces, and allowed into other
    /// apps' Stage Manager sets ("floating windows and system overlays", NSWindow.h). Raw value 0x40151.
    static let collectionBehavior: NSWindow.CollectionBehavior =
        [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllApplications]

    /// The style: borderless and non-activating (an agent app is never active).
    static let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

    /// A configured panel at `frame`, not ordered in: clear, shadowless, click-through, excluded from legacy screen
    /// capture, never hidden with the app, out of the Windows menu, without animation and invisible to VoiceOver.
    static func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: styleMask, backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true          // click-through
        panel.level = level
        panel.collectionBehavior = collectionBehavior
        panel.sharingType = .none                // out of legacy captures; ScreenCaptureKit may still see it (H-W3)
        panel.hidesOnDeactivate = false          // we are an agent app, never active
        panel.canHide = false                    // survives "Hide Others"
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none          // no fade-in
        panel.isReleasedWhenClosed = false       // ARC owns it
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = false
        panel.setAccessibilityElement(false)
        panel.setFrame(frame, display: false)
        return panel
    }
}
