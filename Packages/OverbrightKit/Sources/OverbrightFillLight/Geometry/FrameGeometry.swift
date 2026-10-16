// OverbrightFillLight/Geometry/FrameGeometry.swift — the lit frame of one display (pure). ARCHITECTURE.md §7.6
// ("frame-shaped CAShapeLayer, even-odd, rounded inner corners"), §10.9 (FrameGeometryTests); DESIGN.md §7.7, §11.
import CoreGraphics
import OverbrightCore

/// The shape of the Fill Light on one display, in the frame window's coordinates (origin bottom-left, the window
/// covering the display's whole frame). DESIGN.md §11: the outer edge is the display's frame, the inner edge a
/// rounded rectangle inset by the width with corner radius `min(24, width)`; the top edge starts below the menu bar
/// (on a notched display, below the notch band) so menus stay usable, and in a full-screen Space, where the menu bar
/// hides, it reaches the top.
public nonisolated struct FrameGeometry: Equatable, Sendable {
    /// The Width setting's range in points (DESIGN.md §7.7).
    public static let widthRange: ClosedRange<Double> = 16...120
    /// The largest inner corner radius (DESIGN.md §11).
    public static let maximumInnerCornerRadius: CGFloat = 24

    /// The window's bounds: the display's frame size at origin zero.
    public let bounds: CGRect
    /// The band kept clear at the top for the menu bar (0 in a full-screen Space).
    public let topInset: CGFloat
    /// The lit area's outer edge: the bounds without the top band.
    public let outer: CGRect
    /// The lit area's inner edge (a rounded rectangle).
    public let inner: CGRect
    /// The band's width actually used: the setting clamped to 16…120 pt and to what the display can hold.
    public let width: CGFloat
    /// The inner corners' radius: `min(24, width)`, and never more than half the inner rectangle.
    public let innerCornerRadius: CGFloat

    /// The frame of a display of `displaySize` points.
    /// - Parameters:
    ///   - menuBarHeight: the menu bar's band at the top (`frame.maxY − visibleFrame.maxY`; 0 when it hides itself).
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`, the notch band (0 without a notch).
    ///   - width: the Width setting in points.
    ///   - reachesTop: the display shows a full-screen Space, so there is no menu bar to keep clear.
    public init(displaySize: CGSize, menuBarHeight: CGFloat, safeAreaTop: CGFloat, width: Double, reachesTop: Bool) {
        let size = CGSize(width: max(displaySize.width, 0), height: max(displaySize.height, 0))
        bounds = CGRect(origin: .zero, size: size)
        let band = reachesTop ? 0 : max(menuBarHeight.isFinite ? menuBarHeight : 0, safeAreaTop.isFinite ? safeAreaTop : 0, 0)
        topInset = min(band, size.height / 2)
        outer = CGRect(x: 0, y: 0, width: size.width, height: size.height - topInset)
        let requested = width.isFinite ? min(max(width, Self.widthRange.lowerBound), Self.widthRange.upperBound)
                                       : FillLightSettings.width.defaultValue
        // Keep an inner rectangle of at least 2 pt on a display (or a test size) too small for the band.
        let fits = max((min(outer.width, outer.height) - 2) / 2, 0)
        self.width = min(CGFloat(requested), fits)
        inner = outer.insetBy(dx: self.width, dy: self.width)
        innerCornerRadius = max(min(Self.maximumInnerCornerRadius, self.width, inner.width / 2, inner.height / 2), 0)
    }

    /// The frame as one even-odd path: the outer rectangle plus the inner rounded rectangle.
    public var path: CGPath {
        let path = CGMutablePath()
        guard !outer.isEmpty else { return path }
        path.addRect(outer)
        if !inner.isEmpty {
            path.addRoundedRect(in: inner, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius)
        }
        return path
    }

    /// Whether `point` (window coordinates) is lit.
    public func isLit(_ point: CGPoint) -> Bool { path.contains(point, using: .evenOdd) }
}
