// OverbrightDesign/Styles/LinkButtonStyle.swift — text buttons that read as links ("Learn more", "Why?").
// DESIGN.md §5.10. Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
import SwiftUI

/// Accent-coloured text with the minimum hit height.
public struct LinkButtonStyle: ButtonStyle {
    /// The style.
    public init() {}

    /// The label in the accent colour.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.tint)
            .frame(minHeight: HitTarget.minimum.height)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
