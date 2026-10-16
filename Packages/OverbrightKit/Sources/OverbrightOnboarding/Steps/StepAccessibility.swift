// OverbrightOnboarding/Steps/StepAccessibility.swift — VoiceOver's reading order inside a Welcome step (DESIGN.md
// §8, §15): the step's header first (it also takes VoiceOver focus when the step appears, `StepHeader`), then the stage,
// then the rest of the step's copy and controls. The stage sits above the header on screen, so without this order
// VoiceOver would start a step with its controls.
import SwiftUI

/// VoiceOver's reading order inside a step: the header, then the stage, then the rest of the copy and controls.
nonisolated enum StepAccessibility {
    /// The step's header (it also takes VoiceOver focus when the step appears).
    static let header: Double = 2
    /// The stage.
    static let stage: Double = 1
}

extension View {
    /// A step's root: one VoiceOver container whose children follow `StepAccessibility`'s order.
    func welcomeStepRoot() -> some View {
        accessibilityElement(children: .contain)
    }

    /// The step's header goes first for VoiceOver.
    func welcomeStepHeader() -> some View {
        accessibilitySortPriority(StepAccessibility.header)
    }
}
