// OverbrightAppShellTests/PanelControllerTests.swift — the panel window's rules that need no window on screen
// (DESIGN.md §5.1, §5.12, §2.4): ⌘W closes, ⌘, opens Settings, ⌘Q quits (nothing else is taken); the container is glass
// on macOS 26+, the popover material on 14/15, opaque under Reduce Transparency and Increase Contrast; the panel grows
// to 70 % of the screen's visible height and no further. A closed panel keeps its window but no SwiftUI content
// (DESIGN.md §17: no work while closed), and a reopen during the close's fade keeps its new content. A click on the
// icon that an outside-click monitor saw first closes the panel and leaves it closed (DESIGN.md §4.2). Nothing is
// ordered in: `preparedPanel(takingFocus:)` builds what `show` brings forward, the close's two halves run by hand, and
// a press is decided by `press()` on a manual clock.
import AppKit
import OverbrightCore
import OverbrightPanelUI
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct PanelControllerTests {
    @Test func thePanelTakesOnlyItsOwnCommandKeys() {
        #expect(OverbrightPanel.command(characters: "w", modifiers: .command) == .close)
        #expect(OverbrightPanel.command(characters: ",", modifiers: .command) == .settings)
        #expect(OverbrightPanel.command(characters: "q", modifiers: .command) == .quit)
        #expect(OverbrightPanel.command(characters: "Q", modifiers: .command) == .quit)
        #expect(OverbrightPanel.command(characters: "q", modifiers: [.command, .option]) == nil)
        #expect(OverbrightPanel.command(characters: "w", modifiers: []) == nil)
        #expect(OverbrightPanel.command(characters: "c", modifiers: .command) == nil)        // copy stays with the text
    }

    @Test func theContainerFollowsTheAccessibilityOptions() {
        #expect(PanelContainer.material(reduceTransparency: false, increaseContrast: false, supportsGlass: true) == .glass)
        #expect(PanelContainer.material(reduceTransparency: false, increaseContrast: false, supportsGlass: false) == .popover)
        #expect(PanelContainer.material(reduceTransparency: true, increaseContrast: false, supportsGlass: true) == .opaque)
        #expect(PanelContainer.material(reduceTransparency: false, increaseContrast: true, supportsGlass: false) == .opaque)
        let content = NSView()
        let opaque = PanelContainer.make(around: content, material: .opaque)
        #expect(content.superview === opaque && opaque.layer?.cornerRadius ?? 0 > 0)
    }

    @Test func thePanelGrowsToSeventyPercentOfTheVisibleHeight() {
        let screen = PanelPlacement.Screen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                           visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950))
        let anchor = CGRect(x: 1300, y: 950, width: 38, height: 32)
        let cap = PanelPlacement.maximumHeight(anchor: anchor, screens: [screen], main: screen)
        #expect(cap == (950 * PanelLayout.maximumHeightFraction).rounded(.down))
        #expect(PanelPlacement.height(ideal: 400, anchor: anchor, screens: [screen], main: screen) == 400)
        #expect(PanelPlacement.height(ideal: 2000, anchor: anchor, screens: [screen], main: screen) == cap)
        let frame = PanelPlacement.frame(for: CGSize(width: PanelLayout.width, height: cap), anchor: anchor,
                                         screens: [screen], main: screen)
        #expect(screen.visibleFrame.contains(frame))
    }

    @Test func thePanelWindowIsANonActivatingPopUp() {
        let panel = OverbrightPanel(frame: CGRect(x: 0, y: 0, width: PanelLayout.width, height: 200))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .popUpMenu && !panel.hidesOnDeactivate && panel.canBecomeKey && !panel.canBecomeMain)
        var cancelled = false
        panel.onCancel = { cancelled = true }
        panel.cancelOperation(nil)
        #expect(cancelled)
        #expect(!panel.isVisible)
    }

    @Test func theEndOfACloseReleasesTheContentAndKeepsTheWindow() async {
        _ = NSApplication.shared
        let controller = PanelController(services: .preview())
        let anchorWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 38, height: 24), styleMask: [.borderless],
                                    backing: .buffered, defer: true)
        let anchor = NSView()
        anchorWindow.contentView = anchor
        weak var released: NSView?
        let panel = autoreleasepool {
            let panel = controller.preparedPanel(takingFocus: false)
            released = controller.hostedContent
            #expect(released != nil && panel.contentView != nil)
            controller.installMonitors()
            controller.follow(anchor)
            #expect(controller.watchesOutsideClicks && controller.followsAnchor)
            controller.beginClosing()                                         // the close starts its fade
            #expect(!controller.isShown && !controller.watchesOutsideClicks && !controller.followsAnchor)
            #expect(controller.hostedContent != nil)                          // drawn until the fade ends
            controller.finishClosing()                                        // the fade's completion
            return panel
        }
        #expect(controller.hostedContent == nil && panel.contentView == nil && !controller.isShown)
        #expect(await eventually { released == nil }, "the closed panel's hosting view is still alive")
        let reopened = controller.preparedPanel(takingFocus: false)           // the next opening: same window, new view
        #expect(reopened === panel && controller.hostedContent != nil && panel.contentView != nil)
        controller.finishClosing()                                            // no close pending: nothing happens
        #expect(controller.hostedContent != nil)
    }

    /// The owner's report (2026-10-20): a second click on the icon reopened the panel. The click reached the
    /// outside-click monitor first, which closed the panel, and then the status item's action, which found it closed;
    /// within 0.4 s of an outside-click close that action is the same click and leaves the panel closed, once.
    @Test func aClickOnTheIconRightAfterAnOutsideCloseLeavesThePanelClosed() {
        var clock: CFTimeInterval = 100
        let controller = PanelController(services: .preview())
        controller.now = { clock }
        #expect(!controller.isShown && controller.press() == .open)          // a first click opens it
        controller.recordClose(.outsideClick)                               // the monitor saw the second click first
        clock += 0.05                                                       // the item's action, the same click
        #expect(controller.press() == .staysClosed)
        #expect(controller.press() == .open)                                // the next click opens it again
        controller.recordClose(.outsideClick)
        clock += PanelController.toggleAfterOutsideCloseWindow - 0.001
        #expect(controller.press() == .staysClosed)
    }

    /// A click on the icon 0.4 s or more after an outside-click close, or after any other close, opens the panel.
    @Test func aClickOnTheIconAfterTheWindowReopensThePanel() {
        var clock: CFTimeInterval = 100
        let controller = PanelController(services: .preview())
        controller.now = { clock }
        controller.recordClose(.outsideClick)                               // a click in another app
        clock += PanelController.toggleAfterOutsideCloseWindow
        #expect(controller.press() == .open)
        controller.recordClose(.outsideClick)
        clock += 2
        #expect(controller.press() == .open)
        for cause: PanelController.CloseCause in [.toggle, .escape, .command, .action, .request] {
            controller.recordClose(cause)
            clock += 0.05
            #expect(controller.press() == .open, "\(cause)")
        }
    }

    @Test func aReopenDuringTheFadeKeepsItsNewContent() {
        _ = NSApplication.shared
        let controller = PanelController(services: .preview())
        let panel = controller.preparedPanel(takingFocus: false)
        let first = controller.hostedContent
        controller.beginClosing()
        controller.preparedPanel(takingFocus: false)                          // reopened while panelOut fades
        let reopened = controller.hostedContent
        #expect(reopened != nil && reopened !== first)
        controller.finishClosing()                                            // the old fade's completion comes after
        #expect(controller.hostedContent === reopened && panel.contentView != nil)
    }
}
