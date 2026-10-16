// OverbrightDesign/Styles/ChipButtonStyle.swift — the style of chips that are buttons. DESIGN.md §2.3, §3.1, §5.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. Hit-target widening happens inside the style, never with
// an outer frame (Cranny gotcha); the press scales to 0.97 with the `press` spring, not under Reduce Motion.
import SwiftUI

/// A capsule button with the minimum hit target, the `press` feedback and the capsule focus ring.
public struct ChipButtonStyle: ButtonStyle {
    @Environment(\.overbright) private var theme

    /// The style.
    public init() {}

    /// The label in a capsule hit area of at least `HitTarget.minimum`.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: HitTarget.minimum.width, minHeight: HitTarget.minimum.height)
            .contentShape(Capsule(style: .continuous))
            .overbrightCapsuleFocusRing()
            .scaleEffect(configuration.isPressed && theme.allowsScale ? OverbrightMotion.pressScale : 1)
            .animation(theme.animation(.press), value: configuration.isPressed)
    }
}

#Preview("Button styles") {
    HStack(spacing: Space.l) {
        Button {} label: {
            Text(verbatim: "Limited by macOS")
                .font(OverbrightFont.chip.font)
                .padding(.horizontal, Space.m)
                .frame(height: 20)
                .background(SemanticColor.info.tint, in: Capsule(style: .continuous))
        }
        .buttonStyle(ChipButtonStyle())
        Button {} label: { Image(symbol: .ellipsis) }.buttonStyle(IconButtonStyle())
        Button {} label: { Text(verbatim: "Learn more") }.buttonStyle(LinkButtonStyle())
    }
    .padding()
    .overbrightThemeRoot()
}
