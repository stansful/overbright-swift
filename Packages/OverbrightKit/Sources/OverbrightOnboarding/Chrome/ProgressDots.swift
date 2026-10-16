// OverbrightOnboarding/Chrome/ProgressDots.swift — where you are in the Welcome window: one dot per step, the current one
// stretched into a capsule. VoiceOver reads "Step 2 of 5" (DESIGN.md §8). Ported from Cranny's ProgressDots (the
// owner's MIT code).
import Foundation
import OverbrightDesign
import SwiftUI

/// The Welcome window's progress.
struct ProgressDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 1-based.
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(1...max(count, 1), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: index == current ? Space.xxl : Space.s, height: Space.s)
            }
        }
        .animation(OverbrightTheme(reduceMotion: reduceMotion).animation(.contentSwap), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.label(current: current, count: count)))
    }

    /// "Step 2 of 5"; `bundle` picks a localization in tests.
    static func label(current: Int, count: Int, bundle: Bundle = .module) -> String {
        String(localized: "Step \(current) of \(count)", bundle: bundle,
               comment: "VoiceOver: label of the Welcome window’s progress dots")
    }
}

#Preview("Progress") {
    VStack(spacing: Space.l) {
        ProgressDots(current: 2, count: 5)
        ProgressDots(current: 5, count: 5)
    }
    .padding(Space.xxl)
}
