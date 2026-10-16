// OverbrightAppShell/Panel/PanelPlacement.swift — where the panel goes, as a pure function of the status button's
// window frame and the screens. ARCHITECTURE.md §7.6, §10.0; DESIGN.md §4.4, §5.1; D13. Seeded by WP0a; WP10 owns
// `Panel/`.
//
// A status button counts as placed only when its window overlaps a screen by some area. On macOS 27.0.1 MenuBarAgent
// hosts the menu bar items, and after `NSStatusBar.statusItem(withLength:)` the in-process button window passes
// through unplaced frames: 0 pt high at the origin, then (0, −33, 38, 33) just below the primary screen, then
// (0, 1440, 38, 33) just above a 1440 pt screen, before it lands in the menu bar [VERIFIED in WP0a: about 0.1 s in
// the implementer's runs, more than 1 s in a review run]. Anchoring to any of them puts the panel off screen, so an
// unplaced button gives the top-right corner of the main screen (where the item will appear), and `PanelController`
// re-places the open panel each time the button's window moves.
import AppKit

/// The panel's frame under the status button.
enum PanelPlacement {
    /// A screen as the placement sees it (AppKit coordinates: origin at the bottom-left of the primary screen).
    struct Screen: Equatable {
        /// The whole screen.
        let frame: CGRect
        /// The screen without the menu bar and the Dock.
        let visibleFrame: CGRect

        /// A screen with these frames (tests).
        init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }

        /// The frames of an AppKit screen.
        init(_ screen: NSScreen) {
            self.init(frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }

    /// Distance from the screen edges.
    static let screenMargin: CGFloat = 8
    /// Gap between the menu bar and the panel.
    static let gap: CGFloat = 4
    /// The screen used when AppKit reports none (headless test hosts).
    static let fallbackScreen = Screen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                       visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 870))

    /// The screens AppKit reports now.
    static var currentScreens: [Screen] { NSScreen.screens.map(Screen.init) }

    /// The screen with the key window (AppKit's `NSScreen.main`), nil when AppKit reports none.
    static var currentMainScreen: Screen? { NSScreen.main.map(Screen.init) }

    /// The screen `frame` overlaps most, or nil when it overlaps none by any area (an unplaced status button).
    static func screen(of frame: CGRect, in screens: [Screen]) -> Screen? {
        func overlap(_ screen: Screen) -> CGFloat {
            let shared = screen.frame.intersection(frame)
            return shared.isNull || shared.isEmpty ? 0 : shared.width * shared.height
        }
        guard let best = screens.max(by: { overlap($0) < overlap($1) }), overlap(best) > 0 else { return nil }
        return best
    }

    /// Whether a status button's window frame is on a screen, i.e. placed in a menu bar.
    static func isPlaced(_ frame: CGRect, in screens: [Screen]) -> Bool { screen(of: frame, in: screens) != nil }

    /// The panel's frame for content of `size`.
    /// - `anchor` nil (no status button, the icon is hidden): at the top centre of `main`.
    /// - `anchor` on a screen: centred under it on that screen, inside the screen's margins.
    /// - `anchor` off every screen (the button is not placed yet): at the top-right of `main`'s visible frame.
    /// The result always lies on a screen.
    static func frame(for size: CGSize, anchor: CGRect?, screens: [Screen], main: Screen?) -> CGRect {
        let fallback = main ?? screens.first ?? fallbackScreen
        let placedOn = anchor.flatMap { screen(of: $0, in: screens) }
        let screen = placedOn ?? fallback
        let visible = screen.visibleFrame
        let full = screen.frame
        let midX: CGFloat
        let top: CGFloat
        switch (anchor, placedOn) {
        case let (anchor?, _?):
            midX = anchor.midX
            top = min(anchor.minY, visible.maxY)
        case (_?, nil):
            midX = visible.maxX - screenMargin - size.width / 2
            top = visible.maxY
        case (nil, _):
            midX = visible.midX
            top = visible.maxY
        }
        let x = min(max(midX - size.width / 2, full.minX + screenMargin), full.maxX - screenMargin - size.width)
        let y = max(top - gap - size.height, visible.minY + screenMargin)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
