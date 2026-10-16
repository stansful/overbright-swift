// OverbrightDesign/Styles/IconButtonStyle.swift — glyph-only buttons (the panel's "⋯"). DESIGN.md §2.3, §3.1, §5.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. The hit area is widened inside the style; hovering
// shows a rounded highlight with the `hover` curve; the glyph is secondary until hovered or pressed.
import SwiftUI

/// A borderless glyph button with the minimum hit target.
public struct IconButtonStyle: ButtonStyle {
    /// The style.
    public init() {}

    /// The glyph in a rounded hit area of at least `HitTarget.minimum`.
    public func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.overbright) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
            .frame(minWidth: HitTarget.minimum.width, minHeight: HitTarget.minimum.height)
            .background(shape.fill(Color(nsColor: .quaternarySystemFill)).opacity(isHovered || configuration.isPressed ? 1 : 0))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { inside in
                withAnimation(theme.animation(.hover)) { isHovered = inside }
            }
    }
}
