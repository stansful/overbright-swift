// OverbrightDesign/Tokens/StrokeWidth.swift — stroke and mark sizes. DESIGN.md §2.3, §5.5.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
import CoreGraphics

/// Strokes and slider marks in points.
public nonisolated enum StrokeWidth {
    /// The regular stroke.
    public static let regular: CGFloat = 1
    /// The keyboard focus ring.
    public static let focusRing: CGFloat = 2
    /// The slider track at rest.
    public static let track: CGFloat = 4
    /// The slider track while dragging.
    public static let trackDragging: CGFloat = 6
    /// The Standard detent tick.
    public static let detent = CGSize(width: 1.5, height: 8)
    /// A preset tick.
    public static let presetTick = CGSize(width: 1, height: 5)
    /// The allowed-now marker.
    public static let allowedMarker = CGSize(width: 2, height: 10)
}
