// OverbrightFillLight/Window/FillLightWindowRecipe.swift — the frame window's configuration. ARCHITECTURE.md §7.6
// (the trigger windows' recipe, full frame), §7.3 (the full-screen detector looks at layer-0 windows of other apps
// only), §10.9 (click-through, capture exclusion); DESIGN.md §7.7 (note), §11. Thread: main.
import AppKit

/// The Fill Light window: the same recipe as the trigger and overlay windows (Triggers owns its own copy; layer-1
/// modules never import each other), covering the display's whole frame.
enum FillLightWindowRecipe {
    /// Above the menu bar, the Dock and full-screen windows, below the lock-screen shield. Not layer 0, so the
    /// full-screen detector (which also skips our PID) never takes the frame for a full-screen window.
    static let level: NSWindow.Level = .screenSaver

    /// On every Space, over full-screen Spaces, unaffected by Mission Control, not in ⌘`, allowed into other apps'
    /// Stage Manager sets.
    static let collectionBehavior: NSWindow.CollectionBehavior =
        [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllApplications]

    /// A borderless, non-activating, click-through, capture-excluded panel at `frame`. Not ordered in: the caller
    /// does that once the layers are in place (`defer: true` creates no window device until then).
    static func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                            defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true          // click-through: the light never takes a click
        panel.level = level
        panel.collectionBehavior = collectionBehavior
        panel.sharingType = .none                // left out of screenshots where macOS honours it (DESIGN.md §7.7)
        panel.hidesOnDeactivate = false          // an agent app is never active
        panel.canHide = false                    // survives "Hide Others"
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false       // ARC owns it
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = false
        panel.setAccessibilityElement(false)     // decorative (DESIGN.md §11): not a VoiceOver element
        panel.setFrame(frame, display: false)
        return panel
    }
}
