// OverbrightDesign/Styles/OverbrightLinkButtonStyle.swift — text buttons that read as links ("Learn more", "Why?",
// banner actions). DESIGN.md §5.8, §5.10. Seam written by WP0a (ARCHITECTURE.md §10.0) as `LinkButtonStyle`, renamed by
// WP13 because SwiftUI exports a `LinkButtonStyle` too (§9.2 rule 4); WP9 owns it. The text keeps its
// full contrast (never faded by opacity): a press darkens it with the accent's own pressed state.
import SwiftUI

/// Accent-coloured text with the minimum hit height.
public struct OverbrightLinkButtonStyle: ButtonStyle {
    /// The style.
    public init() {}

    /// The label in the accent colour.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
            .frame(minHeight: HitTarget.minimum.height)
            .contentShape(Rectangle())
            .overbrightFocusRing(cornerRadius: Radius.control)
    }
}
