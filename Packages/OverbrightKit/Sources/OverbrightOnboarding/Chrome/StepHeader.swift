// OverbrightOnboarding/Chrome/StepHeader.swift — a step's headline and its sentence, in system text styles (DESIGN.md
// §8). The headline is a VoiceOver header and takes accessibility focus when the step changes, so VoiceOver starts
// reading the new step. Ported from Cranny's StepHeader (the owner's MIT code).
import OverbrightDesign
import SwiftUI

/// A step's headline and body.
struct StepHeader: View {
    @Environment(\.isStaticSnapshot) private var isStaticSnapshot
    let title: String
    var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(verbatim: title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(verbatim: message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .modifier(FocusOnAppear(isEnabled: !isStaticSnapshot))
    }
}

/// A new step: VoiceOver starts reading it from the top.
private struct FocusOnAppear: ViewModifier {
    @AccessibilityFocusState private var isFocused: Bool
    let isEnabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityFocused($isFocused).onAppear { isFocused = true }
        } else {
            content
        }
    }
}

extension EnvironmentValues {
    /// Rendered with `ImageRenderer` (snapshot tests): skip what it cannot draw, such as accessibility focus state.
    @Entry var isStaticSnapshot = false
}

#Preview("Step header") {
    StepHeader(title: "Your displays", message: "Overbright checks what each display can do.")
        .padding(WelcomeMetrics.inset)
        .frame(width: WelcomeMetrics.window.width)
}
