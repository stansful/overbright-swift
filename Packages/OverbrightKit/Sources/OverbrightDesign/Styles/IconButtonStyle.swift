// OverbrightDesign/Styles/IconButtonStyle.swift — glyph-only buttons (the panel's "⋯"). DESIGN.md §2.3, §5.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
import SwiftUI

/// A borderless glyph button with the minimum hit target.
public struct IconButtonStyle: ButtonStyle {
    /// The style.
    public init() {}

    /// The glyph in a rounded hit area of at least `HitTarget.minimum`.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: HitTarget.minimum.width, minHeight: HitTarget.minimum.height)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
