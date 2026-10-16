// OverbrightOnboarding/Chrome/SelectableCardStyle.swift — the card behind step 3's login options (DESIGN.md §8: "Open
// and turn on · Open, keep off (selected, 'Recommended') · Don't open at login"): a quiet system fill, an accent ring and
// wash when selected (plus a ✓, so colour is not the only cue), a press scale that respects Reduce Motion, and a 2-pt
// focus ring for Full Keyboard Access. Ported from Cranny's SelectableCard (the owner's MIT code).
import OverbrightDesign
import SwiftUI

/// A selectable option card.
struct SelectableCardStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        CardBody(configuration: configuration, isSelected: isSelected)
    }

    private struct CardBody: View {
        @Environment(\.overbright) private var theme
        @Environment(\.isFocused) private var isFocused
        @State private var hovered = false
        let configuration: Configuration
        let isSelected: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: WelcomeMetrics.cardRadius, style: .continuous)
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                            lineWidth: isSelected ? StrokeWidth.focusRing : StrokeWidth.regular))
                .overlay(alignment: .topTrailing) {
                    if isSelected { CheckBadge(isDone: true, size: Space.l).padding(Space.s) }
                }
                .overlay {
                    if isFocused && !isSelected {
                        shape.inset(by: -Radius.focusRingOutset)
                            .strokeBorder(.tint, lineWidth: StrokeWidth.focusRing)
                    }
                }
                .contentShape(shape)
                .scaleEffect(configuration.isPressed && !theme.reduceMotion ? WelcomeMetrics.pressScale : 1)
                .onHover { hovered = $0 }
                .animation(theme.animation(.hover), value: hovered)
                .animation(theme.animation(.press), value: configuration.isPressed)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        private var fill: AnyShapeStyle {
            if isSelected { return AnyShapeStyle(.tint.opacity(WelcomeMetrics.selectedWash)) }
            return AnyShapeStyle(.quaternary.opacity(hovered ? WelcomeMetrics.cardFill.hovered : WelcomeMetrics.cardFill.resting))
        }
    }
}

#Preview("Selectable cards") {
    HStack(spacing: Space.m) {
        Button {} label: { Text(verbatim: "Open, keep off").padding(Space.l) }
            .buttonStyle(SelectableCardStyle(isSelected: true))
        Button {} label: { Text(verbatim: "Don’t open at login").padding(Space.l) }
            .buttonStyle(SelectableCardStyle(isSelected: false))
    }
    .frame(height: 96)
    .padding(Space.xxl)
}
