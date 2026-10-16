// OverbrightAppShellTests/PanelControllerTests.swift — the panel window's rules that need no window on screen
// (DESIGN.md §5.1, §5.12, §2.4): ⌘W closes, ⌘, opens Settings, ⌘Q quits (nothing else is taken); the container is glass
// on macOS 26+, the popover material on 14/15, opaque under Reduce Transparency and Increase Contrast; the panel grows
// to 70 % of the screen's visible height and no further.
import AppKit
import OverbrightPanelUI
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
}
