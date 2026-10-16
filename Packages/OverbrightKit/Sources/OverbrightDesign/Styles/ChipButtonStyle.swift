// OverbrightDesign/Styles/ChipButtonStyle.swift — the style of chips that are buttons. DESIGN.md §2.3, §5.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. Hit-target widening happens inside the style.
import SwiftUI

/// A capsule button with the minimum hit target and the `press` feedback.
public struct ChipButtonStyle: ButtonStyle {
    @Environment(\.overbright) private var theme

    /// The style.
    public init() {}

    /// The label in a capsule hit area of at least `HitTarget.minimum`.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: HitTarget.minimum.width, minHeight: HitTarget.minimum.height)
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed && !theme.reduceMotion ? 0.97 : 1)
    }
}
