// OverbrightOnboarding/Chrome/CheckBadge.swift — the ✓ of something that is done (DESIGN.md §8, §13.1: symbols animate
// only on a state change, never under Reduce Motion). Before that, nothing or a quiet placeholder; colour is never the
// only cue (the glyph changes too). The green is the system's (it adapts to Light/Dark and Increase Contrast). Ported
// from Cranny's CheckBadge (the owner's MIT code).
import OverbrightDesign
import SwiftUI

/// A done/not-done mark.
struct CheckBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isDone: Bool
    var size: CGFloat = WelcomeMetrics.badge

    var body: some View {
        Image(symbol: .checkmarkCircleFill)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(isDone ? AnyShapeStyle(Color.green) : AnyShapeStyle(.quaternary))
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .symbolEffect(.bounce, value: isDone && !reduceMotion)
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
