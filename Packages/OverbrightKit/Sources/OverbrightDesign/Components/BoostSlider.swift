// OverbrightDesign/Components/BoostSlider.swift — the one per-display level control. DESIGN.md §5.5, §12.7, §13.2,
// App. A. Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed (the allowed-now marker is part of the
// slider); WP9 builds the control: detent, shown ticks, fills over the track, hatch, value tag, snapping with haptics,
// steps in stops, one adjustable VoiceOver element with named stops, right-to-left mirroring, disabled halves. The rules
// live in `BoostSliderModel`, the drawing in `BoostSliderTrack`.
import Foundation
import OverbrightCore
import OverbrightPolicy
import SwiftUI

/// The level slider: dim half, Standard detent, boost half with preset ticks and the allowed-now marker.
public struct BoostSlider: View {
    @Binding private var level: LevelPosition
    private let top: Double
    private let allowedNow: Double?
    private let presets: [LevelPreset]
    private let dimEnabled: Bool
    private let boostHalf: BoostHalfState
    private let accessibilityName: String
    private let valueText: (LevelPosition) -> String
    private let onCommit: (LevelPosition) -> Void
    private var spokenValue: ((LevelPosition) -> String)?
    private var extraRangeText: ValueText?
    private var dimmedLevel = LevelMapping.position(forDimLight: 0.25)

    @Environment(\.overbright) private var theme
    @Environment(\.overbrightHaptics) private var haptics
    @Environment(\.layoutDirection) private var direction
    @State private var isDragging = false
    @State private var isHoveringThumb = false
    @State private var scroll = ScrollWheelSteps()
    @FocusState private var isFocused: Bool

    /// - Parameters:
    ///   - level: the display's level (−1 … 1).
    ///   - top: the light gain at the top of the boost half for this display and cap mode (`GainCeiling.sliderTop`).
    ///   - allowedNow: the light gain macOS allows now (the marker), nil when there is no reading.
    ///   - presets: the presets shown on this display (`PresetVisibility.visiblePresets`).
    ///   - dimEnabled: whether the dim half works (a transfer table or the overlay).
    ///   - boostHalf: how the boost half draws and behaves.
    ///   - accessibilityName: the display name in "Level, ‹display name›".
    ///   - valueText: the canonical value text of a position (value tag and VoiceOver value).
    ///   - onCommit: called once when a drag or a key step ends.
    public init(level: Binding<LevelPosition>, top: Double, allowedNow: Double?, presets: [LevelPreset],
                dimEnabled: Bool, boostHalf: BoostHalfState, accessibilityName: String,
                valueText: @escaping (LevelPosition) -> String, onCommit: @escaping (LevelPosition) -> Void) {
        _level = level
        self.top = top; self.allowedNow = allowedNow; self.presets = presets; self.dimEnabled = dimEnabled
        self.boostHalf = boostHalf; self.accessibilityName = accessibilityName
        self.valueText = valueText; self.onCommit = onCommit
    }

    /// The VoiceOver value of a position ("Bright room, 1.29 times"); without it VoiceOver reads `valueText`.
    public func spokenValue(_ text: @escaping (LevelPosition) -> String) -> BoostSlider {
        var copy = self
        copy.spokenValue = text
        return copy
    }

    /// The allowed-now marker's help tag and VoiceOver "Extra range" content (`ValueText.extraRange(allowed:peak:)`).
    public func extraRange(_ text: ValueText?) -> BoostSlider {
        var copy = self
        copy.extraRangeText = text
        return copy
    }

    /// The level of the "Dimmed" VoiceOver action (the last dim level; default 25 % of Standard light).
    public func dimmedLevel(_ level: LevelPosition) -> BoostSlider {
        var copy = self
        copy.dimmedLevel = level
        return copy
    }

    /// The rules of this slider.
    var model: BoostSliderModel {
        BoostSliderModel(top: top, allowedNow: allowedNow, presets: presets, dimEnabled: dimEnabled, boostHalf: boostHalf)
    }

    /// The control.
    public var body: some View {
        let model = self.model
        HStack(spacing: Space.s) {
            endGlyph(.sunMin)
            BoostSliderTrack(model: model, level: level, isDragging: isDragging)
                .contentShape(Rectangle())
                .gesture(drag(model))
                .onContinuousHover { phase in hover(phase) }
                .overlay(alignment: .topLeading) { valueTag(model) }
            endGlyph(.sunMaxFill)
        }
        .help(helpText(model))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.label(accessibilityName)))
        .accessibilityValue(Text(verbatim: spokenValue?(level) ?? valueText(level)))
        .accessibilityAdjustableAction { direction in
            let increment = direction == .increment
            guard direction == .increment || direction == .decrement else { return }
            set(model.adjusted(level, increment: increment), commit: true)
        }
        .accessibilityActions { actions(model) }
        .modifier(ExtraRangeContent(text: extraRangeText))
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .overbrightFocusRing(cornerRadius: Radius.control)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
            guard let key = Self.key(for: press.key, option: press.modifiers.contains(.option), direction: direction)
            else { return .ignored }
            set(model.level(after: key, from: level), commit: true)
            return .handled
        }
        .onHover { inside in
            if inside { scroll.start { notches in scrolled(notches) } } else { scroll.stop() }
        }
        .onDisappear { scroll.stop() }
    }

    // MARK: Pieces

    private func endGlyph(_ symbol: OverbrightSymbol) -> some View {
        Image(symbol: symbol)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(width: 14)
            .accessibilityHidden(true)
    }

    @ViewBuilder private func valueTag(_ model: BoostSliderModel) -> some View {
        if isDragging || isHoveringThumb {
            let base = valueText(level)
            let x = thumbX
            let text = model.isSmallGain && level.isBoost ? CopyFormat.parts(base, ValueText.smallGain()) : base
            Text(verbatim: text)
                .font(OverbrightFont.valueTag.font)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xxs)
                .background(theme.color(.panelBackground), in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .frame(maxWidth: BoostSliderTrack.width)
                .fixedSize()
                .alignmentGuide(.leading) { d in d.width / 2 - x }
                .alignmentGuide(.top) { d in d.height + Space.s }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private func actions(_ model: BoostSliderModel) -> some View {
        let language = CopyLanguage.app
        Button(LevelPreset.standard.localizedName(in: language)) { set(.standard, commit: true) }
        if model.boostEnabled {
            Button(LevelPreset.max.localizedName(in: language)) { set(model.clamped(LevelPreset.max.position), commit: true) }
        }
        if model.dimEnabled {
            Button(CommonNames.dimmed(in: language)) { set(model.clamped(dimmedLevel), commit: true) }
        }
    }

    // MARK: Input

    private var thumbX: CGFloat { CGFloat(BoostSliderModel.fraction(of: level)) * BoostSliderTrack.width }

    private func drag(_ model: BoostSliderModel) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                let fraction = direction.fraction(atPhysicalX: value.location.x, width: BoostSliderTrack.width)
                let speed = abs(Double(value.velocity.width)) / Double(BoostSliderTrack.width / 2)
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
                onCommit(level)
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

    private func scrolled(_ notches: Int) -> Bool {
        let next = model.step(from: level, by: notches)
        guard next != level else { return false }
        set(next, commit: true)
        return true
    }

    private func set(_ next: LevelPosition, commit: Bool) {
        if let pattern = model.haptic(from: level, to: next) { haptics.play(pattern) }
        level = next
        if commit { onCommit(next) }
    }

    private func helpText(_ model: BoostSliderModel) -> String {
        if case let .unavailable(reason) = boostHalf { return reason }
        return model.markerLevel != nil ? extraRangeText?.text ?? "" : ""
    }

    /// The key of a press: ← and → toward the side they point at (a right-to-left slider has its boost end on the
    /// left), ⌥ for the named stops, Home and End.
    static func key(for key: KeyEquivalent, option: Bool, direction: LayoutDirection) -> BoostSliderModel.Key? {
        if key == .home { return .home }
        if key == .end { return .end }
        guard let step = direction.step(for: key) else { return nil }
        switch (step > 0, option) {
        case (true, false): return .stepTowardBoost
        case (false, false): return .stepTowardDim
        case (true, true): return .nextStop
        case (false, true): return .previousStop
        }
    }

    /// "Level, ‹display name›".
    static func label(_ name: String, in language: CopyLanguage = .app) -> String {
        let name = name.overbrightIsolated
        return String(localized: "Level, \(name)", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: label of a display’s level slider; the argument is the display’s name")
    }
}

/// VoiceOver's "Extra range" content of the slider, when there is a reading.
private struct ExtraRangeContent: ViewModifier {
    let text: ValueText?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityCustomContent(Text(verbatim: BoostSlider.extraRangeLabel()),
                                               Text(verbatim: text.accessibilityText))
        } else {
            content
        }
    }
}

extension BoostSlider {
    /// "Extra range": the label of the slider's VoiceOver custom content.
    static func extraRangeLabel(in language: CopyLanguage = .app) -> String {
        String(localized: "Extra range", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: label of the slider’s custom content that says how much extra range macOS allows")
    }
}

#Preview("Level slider") {
    @Previewable @State var boosted = LevelPreset.brightRoom.position
    @Previewable @State var dimmed = LevelMapping.position(forDimLight: 0.25)
    @Previewable @State var off = LevelPreset.brightRoom.position
    let presets = PresetVisibility.visiblePresets(top: 2.587)
    let text: (LevelPosition) -> String = { ValueText.forLevel($0, top: 2.587, presets: presets, isEstimate: true).text }
    VStack(alignment: .leading, spacing: Space.xl) {
        BoostSlider(level: $boosted, top: 2.587, allowedNow: 1.55, presets: presets, dimEnabled: true, boostHalf: .active,
                    accessibilityName: "Built-in Display", valueText: text, onCommit: { _ in })
            .extraRange(ValueText.extraRange(allowed: 1.55, peak: 2.6))
        BoostSlider(level: $dimmed, top: 2.587, allowedNow: nil, presets: presets, dimEnabled: true, boostHalf: .active,
                    accessibilityName: "Built-in Display", valueText: text, onCommit: { _ in })
        BoostSlider(level: $off, top: 2.587, allowedNow: nil, presets: presets, dimEnabled: true, boostHalf: .inactive,
                    accessibilityName: "Built-in Display", valueText: text, onCommit: { _ in })
        BoostSlider(level: .constant(.standard), top: 1, allowedNow: nil, presets: [], dimEnabled: true,
                    boostHalf: .unavailable(reason: "HDR is off"), accessibilityName: "Studio Display",
                    valueText: text, onCommit: { _ in })
    }
    .padding()
    .frame(width: 320)
    .overbrightThemeRoot()
}
