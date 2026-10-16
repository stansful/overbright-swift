// OverbrightOnboarding/Chrome/StepLayout.swift — the shape every step shares (DESIGN.md §8): "The top half is a stage
// (the before/after card or an illustration), the bottom half holds copy and controls on the system background." The
// footer is the window's (`WelcomeFooter`), below this.
import OverbrightDesign
import SwiftUI

/// A step: its stage on top, a divider, then its copy and controls.
struct StepLayout<Stage: View, Content: View>: View {
    private let stage: Stage
    private let content: Content

    /// `stage` fills the top band; `content` starts with the step's `StepHeader`.
    init(@ViewBuilder stage: () -> Stage, @ViewBuilder content: () -> Content) {
        self.stage = stage()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity)
                .frame(height: WelcomeMetrics.stageHeight)
                .clipped()
            Divider()
            VStack(alignment: .leading, spacing: Space.l) { content }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, WelcomeMetrics.inset)
                .padding(.top, Space.xl)
        }
    }
}

#Preview("Step layout") {
    StepLayout {
        Color(nsColor: .underPageBackgroundColor)
    } content: {
        StepHeader(title: "Your displays", message: "Overbright checks what each display can do.")
    }
    .frame(width: WelcomeMetrics.window.width, height: 400)
}
