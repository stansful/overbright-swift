// OverbrightTriggers/Geometry/TriggerGeometry.swift — where the trigger and overlay windows go, as pure functions.
// ARCHITECTURE.md §4.7 (placement: top-right corner, notch alternative), §7.5 (the overlay covers the whole frame),
// §7.6. Tested without a screen (`TriggerGeometryTests`).
import CoreGraphics
import OverbrightCore

/// Window frames in global AppKit coordinates (origin at the bottom-left of the primary screen, y up).
nonisolated enum TriggerGeometry {
    /// The smallest and largest trigger edge in points. 1 pt is 2 × 2 px on Retina; more than a few points would be
    /// visible on an unmasked corner, so a larger request is a lab setting and is capped.
    static let edgeRange: ClosedRange<CGFloat> = 1...16

    /// The trigger window's frame on `screen` for `placement` with an edge of `edgePoints`.
    /// - `.topRightCorner` / `.topLeftCorner`: flush with the screen's top corner (on a notched built-in panel the
    ///   rounded corner hides it; on externals it sits in the menu-bar strip).
    /// - `.notch`: centred in the camera housing, between the two auxiliary areas. Without both areas, or when they
    ///   overlap, it falls back to the top-right corner.
    static func triggerFrame(on screen: ScreenGeometry, placement: TriggerPlacement, edgePoints: Double) -> CGRect {
        triggerFrame(screenFrame: screen.frame, notchLeft: screen.auxiliaryTopLeftArea,
                     notchRight: screen.auxiliaryTopRightArea, placement: placement, edge: clampedEdge(edgePoints))
    }

    /// The same with explicit inputs.
    static func triggerFrame(screenFrame f: CGRect, notchLeft: CGRect?, notchRight: CGRect?,
                             placement: TriggerPlacement, edge e: CGFloat) -> CGRect {
        switch placement {
        case .topRightCorner:
            return CGRect(x: f.maxX - e, y: f.maxY - e, width: e, height: e)
        case .topLeftCorner:
            return CGRect(x: f.minX, y: f.maxY - e, width: e, height: e)
        case .notch:
            guard let left = notchLeft.map({ globalRect($0, in: f) }),
                  let right = notchRight.map({ globalRect($0, in: f) }),
                  right.minX > left.maxX else {
                return triggerFrame(screenFrame: f, notchLeft: nil, notchRight: nil, placement: .topRightCorner, edge: e)
            }
            let x = ((left.maxX + right.minX) / 2 - e / 2).rounded()
            return CGRect(x: x, y: f.maxY - e, width: e, height: e)
        }
    }

    /// The Compatibility overlay's frame: the whole screen, menu bar included (§7.5).
    static func overlayFrame(on screen: ScreenGeometry) -> CGRect { screen.frame }

    /// The auxiliary areas are documented in screen coordinates; accept screen-local values too (hardware check H-T6):
    /// a rect whose centre lies outside the screen frame is taken as local and moved by the frame's origin.
    static func globalRect(_ r: CGRect, in f: CGRect) -> CGRect {
        f.contains(CGPoint(x: r.midX, y: r.midY)) ? r : r.offsetBy(dx: f.minX, dy: f.minY)
    }

    /// A requested edge clamped to `edgeRange`; a non-finite request gives the minimum.
    static func clampedEdge(_ points: Double) -> CGFloat {
        guard points.isFinite else { return edgeRange.lowerBound }
        return min(max(CGFloat(points), edgeRange.lowerBound), edgeRange.upperBound)
    }

    /// A drawable edge in pixels for an edge in points (at least 1 px).
    static func pixelEdge(points: CGFloat, backingScale: CGFloat) -> Int {
        let pixels = (points * (backingScale.isFinite && backingScale > 0 ? backingScale : 1)).rounded()
        return max(1, Int(pixels))
    }
}
