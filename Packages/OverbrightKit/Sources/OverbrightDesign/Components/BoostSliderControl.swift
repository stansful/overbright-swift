// OverbrightDesign/Components/BoostSliderControl.swift — the level slider as drawn and driven: the track with its help
// tags and value tag, dragging with snapping and haptics, the keys, scroll-wheel notches, VoiceOver, and the slider's
// one focusable element. DESIGN.md §5.5, §5.12, §12.7, §13.2, §15. `BoostSlider` holds what the host gives; this view
// holds the state. It is generic over the focus value so that a host's `FocusState` binds the same element that takes
// the keys (`BoostSlider.focusBinding(_:equals:)`): one Tab stop, one ring.
import Foundation
import OverbrightCore
import OverbrightPolicy
import SwiftUI

/// The slider's state and input, focused through `focus == value`.
struct BoostSliderControl<Focus: Hashable>: View {
    private let slider: BoostSlider
    private let focusValue: Focus
    @Binding private var level: LevelPosition
    @FocusState.Binding private var focus: Focus?

    @Environment(\.overbright) private var theme
    @Environment(\.overbrightHaptics) private var haptics
    @Environment(\.layoutDirection) private var direction
    @State private var isDragging = false
    @State private var isHoveringThumb = false
    @State private var isPointerOver: Bool
    @State private var scroll = ScrollWheelSteps()

    /// The control of `slider`, focused while `focus` is `value`.
    init(_ slider: BoostSlider, focus: FocusState<Focus?>.Binding, equals value: Focus) {
        self.slider = slider
        focusValue = value
        _level = slider.level
        _focus = focus
        _isPointerOver = State(initialValue: slider.startsUnderPointer)
    }

    var body: some View {
        let model = slider.model
        BoostSliderTrack(model: model, level: level, isDragging: isDragging)
            .overlay { halfHelp(model) }
            .contentShape(Rectangle())
            .gesture(drag(model))
            .onContinuousHover { phase in hover(phase) }
            .overlay(alignment: .topLeading) { valueTag }
            .background { if isPointerOver { ScrollWheelAnchor(steps: scroll, target: scrollTarget(model)) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: BoostSlider.label(slider.accessibilityName)))
            .accessibilityValue(Text(verbatim: spokenValue))
            .accessibilityHint(Text(verbatim: BoostSlider.disabledHint(model, dimReason: slider.dimHalfReason)))
            .accessibilityAdjustableAction { direction in
                guard direction == .increment || direction == .decrement else { return }
                set(model.adjusted(level, increment: direction == .increment), commit: true)
            }
            .accessibilityActions { actions(model) }
            .modifier(BoostSliderExtraRange(text: extraRange(model)))
            // Inside the focusable element, `\.isFocused` is this element's own focus, whoever binds it.
            .overbrightFocusRing(cornerRadius: Radius.control)
            .focusable()
            .focusEffectDisabled()
            .focused($focus, equals: focusValue)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
                guard let key = BoostSlider.key(for: press.key, option: press.modifiers.contains(.option),
                                                direction: direction) else { return .ignored }
                set(model.level(after: key, from: level), commit: true)
                return .handled
            }
            .onContinuousHover { phase in pointer(phase) }
            .onDisappear {
                isPointerOver = false
                scroll.stop()
            }
    }

    // MARK: Pieces

    @ViewBuilder private var valueTag: some View {
        if isDragging || isHoveringThumb {
            BoostSliderValueTag(text: slider.valueText(level), thumbX: thumbX)
        }
    }

    private var spokenValue: String {
        slider.spokenValue?(level)
            ?? BoostSlider.spoken(slider.valueText(level), at: level, top: slider.top, presets: slider.presets)
    }

    /// The help tags of the halves, each over its own half only (`helpTags`); the leading half is the dim one, and the
    /// HStack mirrors right to left with the track.
    private func halfHelp(_ model: BoostSliderModel) -> some View {
        let tags = BoostSlider.helpTags(model, dimReason: slider.dimHalfReason, extraRange: extraRange(model))
        return HStack(spacing: 0) {
            helpRegion(tags.dim)
            helpRegion(tags.boost)
        }
        .frame(width: BoostSliderTrack.width)
    }

    @ViewBuilder private func helpRegion(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            Rectangle().fill(.clear).contentShape(Rectangle()).help(text)
        } else {
            Color.clear
        }
    }

    private func extraRange(_ model: BoostSliderModel) -> ValueText? {
        BoostSlider.extraRange(model, given: slider.extraRangeText)
    }

    @ViewBuilder private func actions(_ model: BoostSliderModel) -> some View {
        let language = CopyLanguage.app
        Button(LevelPreset.standard.localizedName(in: language)) { set(.standard, commit: true) }
        if model.boostEnabled {
            Button(LevelPreset.max.localizedName(in: language)) { set(model.clamped(LevelPreset.max.position), commit: true) }
        }
        if model.dimEnabled {
            Button(CommonNames.dimmed(in: language)) { set(model.clamped(slider.dimmedLevel), commit: true) }
        }
    }

    // MARK: Input

    private var thumbX: CGFloat { BoostSliderTrack.x(of: level) }

    private func drag(_ model: BoostSliderModel) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                let fraction = BoostSliderTrack.fraction(atPhysicalX: value.location.x, direction: direction)
                // Level units per second: the thumb's travel spans the two units from the dim floor to Max.
                let speed = abs(Double(value.velocity.width)) / Double(BoostSliderTrack.travel / 2)
                let next = model.dragged(toFraction: fraction, speed: speed)
                let snapped = next != BoostSliderModel.level(atFraction: fraction)
                if let pattern = model.haptic(from: level, to: next) { haptics.play(pattern) }
                if snapped, next != level {
                    withAnimation(theme.animation(.detentSnap)) { level = next }
                } else {
                    level = next
                }
            }
            .onEnded { _ in
                isDragging = false
                slider.onCommit(level)
            }
    }

    private func hover(_ phase: HoverPhase) {
        switch phase {
        case let .active(location):
            let x = CGFloat(direction.fraction(atPhysicalX: location.x, width: BoostSliderTrack.width))
                * BoostSliderTrack.width
            isHoveringThumb = abs(x - thumbX) <= HitTarget.sliderThumb / 2
        case .ended:
            isHoveringThumb = false
        }
    }

    /// The pointer over the control: scroll notches step the level while it is there. Every move (re)starts the
    /// listener, so it comes back after its window resigned key or was hidden under the pointer.
    private func pointer(_ phase: HoverPhase) {
        switch phase {
        case .active:
            if !isPointerOver { isPointerOver = true }
            scroll.start(scrollTarget(slider.model))
        case .ended:
            isPointerOver = false
            scroll.stop()
        }
    }

    /// What scrolling does now: whole notches step the level (and are consumed only when it moved); part of a notch
    /// is taken while a notch that way would still move it.
    private func scrollTarget(_ model: BoostSliderModel) -> ScrollWheelSteps.Target {
        ScrollWheelSteps.Target(direction: direction,
                                canMove: { notches in model.step(from: level, by: notches) != level },
                                step: { notches in scrolled(notches, model) })
    }

    private func scrolled(_ notches: Int, _ model: BoostSliderModel) -> Bool {
        let next = model.step(from: level, by: notches)
        guard next != level else { return false }
        set(next, commit: true)
        return true
    }

    private func set(_ next: LevelPosition, commit: Bool) {
        if let pattern = slider.model.haptic(from: level, to: next) { haptics.play(pattern) }
        level = next
        if commit { slider.onCommit(next) }
    }
}

#Preview("Level slider · the host's focus") {
    @Previewable @State var level = LevelPreset.brightRoom.position
    @Previewable @FocusState var focus: Int?
    let presets = PresetVisibility.visiblePresets(top: 1.667)
    VStack(alignment: .leading, spacing: Space.xl) {
        ForEach(0..<2, id: \.self) { index in
            BoostSlider(level: $level, top: 1.667, allowedNow: nil, presets: presets, dimEnabled: true,
                        boostHalf: .active, accessibilityName: "Display \(index + 1)",
                        valueText: { ValueText.forLevel($0, top: 1.667, presets: presets, isEstimate: true).text },
                        onCommit: { _ in })
                .focusBinding($focus, equals: index)
        }
    }
    .padding()
    .overbrightThemeRoot()
}
