// OverbrightOnboarding/Chrome/StepLayout.swift — the shape every step shares (DESIGN.md §8): "The top half is a stage
// (the before/after card or an illustration), the bottom half holds copy and controls on the system background." One
// split on every step (WP14 C-ONBOARD-1): the stage on top, a divider, then the step's headline and body, then its
// controls. Steps whose controls need the room (2 Displays, 3 Defaults) take the compact stage, a band of glyphs; the
// others the full stage. The footer is the window's (`WelcomeFooter`), below this.
import OverbrightDesign
import SwiftUI

/// The height of a step's stage.
nonisolated enum StageSize: Hashable {
    /// The full stage: the before/after card, the menu bar and key caps, an illustration.
    case regular
    /// A band of glyphs, for a step whose controls need the room.
    case compact

    /// The stage's height in the window.
    var height: CGFloat {
        switch self {
        case .regular: WelcomeMetrics.stageHeight
        case .compact: WelcomeMetrics.compactStageHeight
        }
    }

    /// Where the step's headline starts, from the top of the window: under the stage, its divider and the copy's
    /// top padding.
    var headlineTop: CGFloat { height + StrokeWidth.regular + WelcomeMetrics.copyTopPadding }
}

/// A step: its stage on top, a divider, then its copy and controls.
struct StepLayout<Stage: View, Content: View>: View {
    private let size: StageSize
    private let stage: Stage
    private let content: Content

    /// `stage` fills the top band of `size`; `content` starts with the step's `StepHeader`.
    init(stage size: StageSize = .regular, @ViewBuilder stage: () -> Stage, @ViewBuilder content: () -> Content) {
        self.size = size
        self.stage = stage()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .clipped()
            Divider()
            VStack(alignment: .leading, spacing: Space.l) { content }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, WelcomeMetrics.inset)
                .padding(.top, WelcomeMetrics.copyTopPadding)
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

#Preview("Step layout · compact stage") {
    StepLayout(stage: .compact) {
        Color(nsColor: .underPageBackgroundColor)
    } content: {
        StepHeader(title: "Your displays", message: "Overbright checks what each display can do.")
    }
    .frame(width: WelcomeMetrics.window.width, height: 400)
}
