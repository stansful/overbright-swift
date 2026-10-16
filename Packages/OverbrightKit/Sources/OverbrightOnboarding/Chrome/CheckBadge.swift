// OverbrightOnboarding/Chrome/CheckBadge.swift — the ✓ of something that is done (DESIGN.md §8, §13.1: symbols animate
// only on a state change, never under Reduce Motion: `theme.animatesSymbols`). Before that, nothing or a quiet
// placeholder; colour is never the only cue (the glyph changes too). The green is Design's `SemanticColor.success`, the
// system's green (it adapts to Light/Dark and Increase Contrast). Ported from Cranny's CheckBadge (the owner's MIT code).
import OverbrightDesign
import SwiftUI

/// A done/not-done mark.
struct CheckBadge: View {
    @Environment(\.overbright) private var theme
    let isDone: Bool
    var size: CGFloat = WelcomeMetrics.badge

    var body: some View {
        Image(symbol: .checkmarkCircleFill)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(isDone ? AnyShapeStyle(SemanticColor.success.color) : AnyShapeStyle(.quaternary))
            .contentTransition(theme.animatesSymbols ? .symbolEffect(.replace) : .identity)
            .symbolEffect(.bounce, value: isDone && theme.animatesSymbols)
            .accessibilityHidden(true)
    }
}

#Preview("Check badge") {
    HStack(spacing: Space.xl) {
        CheckBadge(isDone: false)
        CheckBadge(isDone: true)
    }
    .padding(Space.xxl)
}
