// OverbrightAppShell/StatusItem/IconVisibilityCheck.swift — is the status item really on screen? The pure decision of
// the visibility check. ARCHITECTURE.md §7.6 (the button's window exists, `isVisible`, its occlusion state contains
// `.visible`, and on a notched screen its frame lies inside `auxiliaryTopLeftArea` or `auxiliaryTopRightArea`, not
// behind the notch); DESIGN.md §4.4; D13.
import AppKit
import OverbrightCore

/// The visibility check, as a function of what AppKit reports.
enum IconVisibilityCheck {
    /// The status button's window as the check sees it.
    struct Window: Equatable {
        /// `isVisible`.
        var isVisible: Bool
        /// `occlusionState` contains `.visible`.
        var isUnoccluded: Bool
        /// The window's frame (AppKit coordinates).
        var frame: CGRect
    }

    /// A screen as the check sees it.
    struct Screen: Equatable {
        /// The whole screen.
        var frame: CGRect
        /// The menu bar areas left and right of the notch (nil on a screen without one).
        var auxiliaryTopLeft: CGRect?
        /// See `auxiliaryTopLeft`.
        var auxiliaryTopRight: CGRect?

        /// A screen with these areas (tests).
        init(frame: CGRect, auxiliaryTopLeft: CGRect? = nil, auxiliaryTopRight: CGRect? = nil) {
            self.frame = frame; self.auxiliaryTopLeft = auxiliaryTopLeft; self.auxiliaryTopRight = auxiliaryTopRight
        }

        /// The areas of an AppKit screen.
        init(_ screen: NSScreen) {
            self.init(frame: screen.frame, auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                      auxiliaryTopRight: screen.auxiliaryTopRightArea)
        }

        /// The screen has a notch.
        var hasNotch: Bool { auxiliaryTopLeft != nil || auxiliaryTopRight != nil }
    }

    /// How far the button may overhang an auxiliary area (rounding of the menu bar layout).
    static let tolerance: CGFloat = 1

    /// The icon's visibility: hidden by the user when General ▸ Show menu bar icon is off; else visible only when the
    /// button's window exists, is visible, is not occluded and lies on a screen, beside the notch on a notched one.
    static func evaluate(window: Window?, screens: [Screen], showsIcon: Bool) -> MenuBarIconVisibility {
        guard showsIcon else { return .hiddenByUser }
        guard let window, window.isVisible, window.isUnoccluded, window.frame.width > 0, window.frame.height > 0,
              let screen = screen(of: window.frame, in: screens) else { return .notVisible }
        guard screen.hasNotch else { return .visible }
        let areas = [screen.auxiliaryTopLeft, screen.auxiliaryTopRight].compactMap { $0 }
        let inside = areas.contains { $0.insetBy(dx: -tolerance, dy: -tolerance).contains(window.frame) }
        return inside ? .visible : .notVisible
    }

    /// The screen `frame` overlaps most, nil when it overlaps none.
    static func screen(of frame: CGRect, in screens: [Screen]) -> Screen? {
        func overlap(_ screen: Screen) -> CGFloat {
            let shared = screen.frame.intersection(frame)
            return shared.isNull || shared.isEmpty ? 0 : shared.width * shared.height
        }
        guard let best = screens.max(by: { overlap($0) < overlap($1) }), overlap(best) > 0 else { return nil }
        return best
    }
}
