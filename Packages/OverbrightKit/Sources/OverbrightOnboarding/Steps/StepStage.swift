// OverbrightOnboarding/Steps/StepStage.swift — the stage band of a step (DESIGN.md §8: "The top half is a stage (the
// before/after card or an illustration), the bottom half holds copy and controls on the system background"): an
// under-page background, its content kept clear of the hidden title bar and its close button. VoiceOver reads a step's
// header first (the stage gets a lower sort priority than the step's copy, `StepAccessibility`).
import AppKit
import OverbrightDesign
import SwiftUI

/// The stage of a step.
struct StepStage<Content: View>: View {
    private let content: Content

    /// A stage around `content`, which is laid out in the stage's content area.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, StepMetrics.titleBarInset)
            .padding(.bottom, StepMetrics.stageBottomInset)
            .padding(.horizontal, WelcomeMetrics.inset)
            .background(Color(nsColor: .underPageBackgroundColor))
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(StepAccessibility.stage)
    }
}

#Preview("Stage") {
    StepLayout {
        StepStage { Text(verbatim: "Stage") }
    } content: {
        StepHeader(title: "Your displays", message: "Overbright checks what each display can do.").welcomeStepHeader()
    }
    .welcomeStepRoot()
    .frame(width: WelcomeMetrics.window.width, height: 400)
}
