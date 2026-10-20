// OverbrightTriggers/Geometry/ScreenGeometry.swift — what the window code needs to know about one screen.
// ARCHITECTURE.md §4.7 (placement), §7.6 (trigger windows).
import CoreGraphics

/// The AppKit geometry of one display's screen, read fresh from `NSScreen` (or a test fixture).
nonisolated struct ScreenGeometry: Hashable, Sendable {
    /// `NSScreen.frame` in global AppKit coordinates (origin at the bottom-left of the primary screen), menu bar
    /// included.
    var frame: CGRect
    /// `NSScreen.auxiliaryTopLeftArea`: the menu-bar strip left of the camera housing (nil without a notch).
    var auxiliaryTopLeftArea: CGRect?
    /// `NSScreen.auxiliaryTopRightArea`: the strip right of the camera housing (nil without a notch).
    var auxiliaryTopRightArea: CGRect?
    /// `NSScreen.backingScaleFactor` (2 on Retina).
    var backingScaleFactor: CGFloat

    init(frame: CGRect, auxiliaryTopLeftArea: CGRect? = nil, auxiliaryTopRightArea: CGRect? = nil,
         backingScaleFactor: CGFloat = 2) {
        self.frame = frame
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
        self.backingScaleFactor = backingScaleFactor
    }
}
