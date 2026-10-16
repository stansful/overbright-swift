// OverbrightOnboarding/Chrome/SelectableCardStyle.swift — the card behind step 3's login options (DESIGN.md §8: "Open
// and turn on · Open, keep off (selected, 'Recommended') · Don't open at login"): a quiet system fill, an accent ring and
// wash when selected (plus a ✓, so colour is not the only cue), a press scale that respects Reduce Motion, and the
// concentric focus ring of every Overbright control (`.overbrightFocusRing`, DESIGN.md §5.12, §15: 2 pt, outset 3, after
// keyboard use), on the selected card too: its selection ring sits on the card's edge, the focus ring outside it, so
// focus always changes what the card looks like (WCAG 2.4.7). Ported from Cranny's SelectableCard (the owner's MIT
// code).
import OverbrightDesign
import SwiftUI

/// A selectable option card.
struct SelectableCardStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        CardBody(configuration: configuration, isSelected: isSelected)
    }

    /// Reads the button's focus (the environment describes the focusable button inside its style).
    private struct CardBody: View {
        @Environment(\.isFocused) private var isFocused
        let configuration: Configuration
        let isSelected: Bool

        var body: some View {
            SelectableCard(isSelected: isSelected, isFocused: isFocused, isPressed: configuration.isPressed) {
                configuration.label
            }
        }
    }
}

/// What a selectable card looks like: selected or not, focused or not, pressed or not (tests draw it focused).
struct SelectableCard<Label: View>: View {
    @Environment(\.overbright) private var theme
    @State private var hovered = false
    let isSelected: Bool
    let isFocused: Bool
    var isPressed = false
    @ViewBuilder let label: Label

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WelcomeMetrics.cardRadius, style: .continuous)
        label
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                        lineWidth: isSelected ? StrokeWidth.focusRing : StrokeWidth.regular))
            .overlay(alignment: .topTrailing) {
                if isSelected { CheckBadge(isDone: true, size: Space.l).padding(Space.s) }
            }
            .overbrightFocusRing(cornerRadius: WelcomeMetrics.cardRadius, isFocused: isFocused)
            .contentShape(shape)
            .scaleEffect(isPressed && !theme.reduceMotion ? WelcomeMetrics.pressScale : 1)
            .onHover { hovered = $0 }
            .animation(theme.animation(.hover), value: hovered)
            .animation(theme.animation(.press), value: isPressed)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.tint.opacity(WelcomeMetrics.selectedWash)) }
        return AnyShapeStyle(.quaternary.opacity(hovered ? WelcomeMetrics.cardFill.hovered : WelcomeMetrics.cardFill.resting))
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

#Preview("Selectable cards · focused") {
    HStack(spacing: Space.l) {
        SelectableCard(isSelected: true, isFocused: true) { Text(verbatim: "Open, keep off").padding(Space.l) }
        SelectableCard(isSelected: false, isFocused: true) { Text(verbatim: "Don’t open at login").padding(Space.l) }
    }
    .frame(height: 96)
    .padding(Space.xxl)
    .onAppear { KeyboardInteraction.shared.record(isKey: true) }
}
