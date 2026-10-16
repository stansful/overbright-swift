// OverbrightOnboarding/Steps/StepCardBackground.swift — the card a group of controls sits on inside a step's stage
// (step 2's display rows, step 3's switches, step 4's menu bar strip), with DESIGN.md §2.1's `card` and `cardStroke`
// rules: the window background with a half-strength separator hairline; with Increase Contrast an opaque control
// background and a full-strength hairline. Colours are the system's; the theme decides (§2.0 rule 2).
import AppKit
import OverbrightDesign
import SwiftUI

/// A step card's fill and hairline.
struct StepCardBackground: ViewModifier {
    @Environment(\.overbright) private var theme
    /// The card's corner radius.
    var cornerRadius = WelcomeMetrics.cardRadius
    /// The fill's opacity (the menu bar strip is a lighter card).
    var fillOpacity: Double = 1

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let highContrast = theme.palette == .highContrast
        content
            .background(highContrast ? Color(nsColor: .controlBackgroundColor)
                        : Color(nsColor: .windowBackgroundColor).opacity(fillOpacity), in: shape)
            .overlay(shape.strokeBorder(Color(nsColor: .separatorColor).opacity(highContrast ? 1 : StepMetrics.hairline),
                                        lineWidth: StrokeWidth.regular))
    }
}

extension View {
    /// Puts the view on a step card (`StepCardBackground`).
    func stepCard(cornerRadius: CGFloat = WelcomeMetrics.cardRadius, fillOpacity: Double = 1) -> some View {
        modifier(StepCardBackground(cornerRadius: cornerRadius, fillOpacity: fillOpacity))
    }
}

#Preview("Step card") {
    Text(verbatim: "Pause in Low Power Mode")
        .padding(Space.m)
        .stepCard()
        .padding(Space.xxl)
        .background(Color(nsColor: .underPageBackgroundColor))
}
