// OverbrightOnboarding/Steps/StepCardBackground.swift — the card a group of controls sits on inside a step (step 2's
// display rows, step 3's switches, step 4's menu bar strip): Design's `card` fill and `cardStroke` hairline (DESIGN.md
// §2.1: `quaternarySystemFill` with a half-strength separator; with Increase Contrast an opaque control background
// and a full-strength hairline), resolved by the theme (§2.0 rules 1–2).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// A step card's fill and hairline.
struct StepCardBackground: ViewModifier {
    @Environment(\.overbright) private var theme
    /// The card's corner radius.
    var cornerRadius = WelcomeMetrics.cardRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(theme.color(.card), in: shape)
            .overlay(shape.strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
    }
}

extension View {
    /// Puts the view on a step card (`StepCardBackground`).
    func stepCard(cornerRadius: CGFloat = WelcomeMetrics.cardRadius) -> some View {
        modifier(StepCardBackground(cornerRadius: cornerRadius))
    }
}

#Preview("Step card") {
    let services = WelcomePreview.services()
    Text(verbatim: services.displays.displays.first?.name ?? "Built-in Retina Display")
        .padding(Space.m)
        .stepCard()
        .padding(Space.xxl)
        .overbrightThemeRoot()
}
