// OverbrightOnboarding/Steps/StepStage.swift — the stage band of a step (DESIGN.md §8: "The top half is a stage (the
// before/after card or an illustration), the bottom half holds copy and controls on the system background"): an
// under-page background, its content kept clear of the hidden title bar and its close button. The compact stage of
// steps 2 and 3 (`StageSize.compact`) holds a centred row of glyphs (`StageGlyphs`), which sits clear of the window
// buttons at the leading edge. VoiceOver reads a step's header first (the stage gets a lower sort priority than the
// step's copy, `StepAccessibility`).
import AppKit
import OverbrightDesign
import SwiftUI

/// The stage of a step.
struct StepStage<Content: View>: View {
    private let size: StageSize
    private let content: Content

    /// A stage of `size` around `content`, which is laid out in the stage's content area.
    init(_ size: StageSize = .regular, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        Group {
            switch size {
            case .regular:
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, StepMetrics.titleBarInset)
                    .padding(.bottom, StepMetrics.stageBottomInset)
            case .compact:
                content
                    .frame(maxWidth: StepMetrics.compactStageContentWidth, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, WelcomeMetrics.inset)
        .background(Color(nsColor: .underPageBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(StepAccessibility.stage)
    }
}

/// A row of glyphs on a compact stage: the displays of step 2, the guards of step 3 (decorative, VoiceOver skips it).
struct StageGlyphs: View {
    let symbols: [OverbrightSymbol]

    var body: some View {
        HStack(spacing: Space.l) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Image(symbol: symbol)
                    .font(.title3)
            }
        }
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
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

#Preview("Compact stage") {
    StepLayout(stage: .compact) {
        StepStage(.compact) { StageGlyphs(symbols: [.laptopComputer, .display]) }
    } content: {
        StepHeader(title: "Your displays", message: "Overbright checks what each display can do.").welcomeStepHeader()
    }
    .welcomeStepRoot()
    .frame(width: WelcomeMetrics.window.width, height: 400)
}
