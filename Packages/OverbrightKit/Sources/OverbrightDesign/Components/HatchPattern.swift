// OverbrightDesign/Components/HatchPattern.swift — the `inactiveHatch` token's lines. DESIGN.md §2.1, §5.5, §15:
// "nothing is brighter" and "not allowed now" are a hatch, not a colour (Differentiate Without Color). 45° lines,
// 1 pt wide, every 3 pt, drawn over the track in `secondaryLabelColor` (`labelColor` under Increase Contrast).
import SwiftUI

/// Parallel 45° lines across the rectangle (stroke it with `StrokeWidth.hatchLine` in `OverbrightColor.inactiveHatch`).
public nonisolated struct HatchPattern: Shape {
    /// The distance between lines, measured along the edge.
    public var spacing: CGFloat

    /// A hatch with lines every `spacing` points.
    public init(spacing: CGFloat = StrokeWidth.hatchSpacing) { self.spacing = max(spacing, 1) }

    /// The lines, clipped to `rect` by the caller (`.clipShape`).
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}
