// OverbrightAppShellTests/PanelPlacementTests.swift — the panel always opens on a screen (ARCHITECTURE.md §7.6,
// DESIGN.md §5.1, D13): under a placed status button, at the top-right of the main screen while the button is not
// placed (on macOS 27.0.1 it passes through (0, −33, 38, 33) and (0, 1440, 38, 33) after launch), at the top centre
// without a button.
import CoreGraphics
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct PanelPlacementTests {
    /// One 2560 × 1440 display with a 30 pt menu bar.
    private let display = PanelPlacement.Screen(frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                                                visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1410))
    /// A second display to the right of it.
    private let right = PanelPlacement.Screen(frame: CGRect(x: 2560, y: 0, width: 1512, height: 982),
                                              visibleFrame: CGRect(x: 2560, y: 0, width: 1512, height: 949))
    private let size = CGSize(width: 320, height: 151)

    /// The unplaced frames AppKit reports right after `statusItem(withLength:)` (logged on macOS 27.0.1, in order).
    @Test func unplacedButtonsAreNotPlaced() {
        #expect(!PanelPlacement.isPlaced(CGRect(x: 0, y: 0, width: 38, height: 0), in: [display]))
        #expect(!PanelPlacement.isPlaced(CGRect(x: 0, y: -33, width: 38, height: 33), in: [display]))
        #expect(!PanelPlacement.isPlaced(CGRect(x: 0, y: 1440, width: 38, height: 33), in: [display]))
        #expect(!PanelPlacement.isPlaced(.zero, in: [display]))
        #expect(!PanelPlacement.isPlaced(CGRect(x: 1964, y: 1408, width: 38, height: 33), in: []))
        #expect(PanelPlacement.isPlaced(CGRect(x: 1964, y: 1408, width: 38, height: 33), in: [display]))
    }

    /// The launch bug of WP0a: an off-screen anchor gave a panel below the screen. Now it opens at the top-right of
    /// the main screen's visible frame.
    @Test func offScreenAnchorGivesAnOnScreenPanel() {
        let frame = PanelPlacement.frame(for: size, anchor: CGRect(x: 0, y: -33, width: 38, height: 33),
                                         screens: [display], main: display)
        #expect(display.visibleFrame.contains(frame))
        #expect(frame.maxX == display.frame.maxX - PanelPlacement.screenMargin)
        #expect(frame.maxY == display.visibleFrame.maxY - PanelPlacement.gap)
        #expect(frame.size == size)
    }

    /// A placed button: centred under it, just below the menu bar.
    @Test func placedAnchorCentresThePanelUnderIt() {
        let anchor = CGRect(x: 1964, y: 1408, width: 38, height: 33)
        let frame = PanelPlacement.frame(for: size, anchor: anchor, screens: [display], main: display)
        #expect(frame.midX == anchor.midX)
        #expect(frame.maxY == anchor.minY - PanelPlacement.gap)
        #expect(display.frame.contains(frame))
    }

    /// Near the screen edge the panel stays inside the margins.
    @Test func panelStaysInsideTheScreenMargins() {
        let anchor = CGRect(x: 2540, y: 1408, width: 38, height: 33)
        let frame = PanelPlacement.frame(for: size, anchor: anchor, screens: [display], main: display)
        #expect(frame.maxX == display.frame.maxX - PanelPlacement.screenMargin)
    }

    /// A button in the second display's menu bar anchors the panel on that display, whatever the main screen is.
    @Test func anchorOnASecondDisplay() {
        let anchor = CGRect(x: 3800, y: 950, width: 38, height: 33)
        let frame = PanelPlacement.frame(for: size, anchor: anchor, screens: [display, right], main: display)
        #expect(right.frame.contains(frame))
        #expect(frame.midX == anchor.midX)
    }

    /// No button (the icon is hidden): the top centre of the main screen.
    @Test func noAnchorGivesTheTopCentre() {
        let frame = PanelPlacement.frame(for: size, anchor: nil, screens: [display, right], main: right)
        #expect(frame.midX == right.visibleFrame.midX)
        #expect(frame.maxY == right.visibleFrame.maxY - PanelPlacement.gap)
    }

    /// AppKit reports no screen (a headless host): still a frame on the fallback screen.
    @Test func noScreensGivesTheFallbackScreen() {
        let frame = PanelPlacement.frame(for: size, anchor: CGRect(x: 0, y: -33, width: 38, height: 33), screens: [],
                                         main: nil)
        #expect(PanelPlacement.fallbackScreen.frame.contains(frame))
    }
}
