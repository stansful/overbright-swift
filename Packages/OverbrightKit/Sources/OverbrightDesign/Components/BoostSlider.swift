// OverbrightDesign/Components/BoostSlider.swift — the one per-display level control. DESIGN.md §5.5, §12.7, §13.2,
// App. A. Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed (the allowed-now marker is part of the
// slider); WP9 builds the control: detent, shown ticks, fills over the track, hatch, value tag, snapping with haptics,
// steps in stops, one adjustable VoiceOver element with named stops, right-to-left mirroring, disabled halves with their
// help tags. The rules live in `BoostSliderModel`, the drawing in `BoostSliderTrack` and `BoostSliderValueTag`, the
// input and focus in `BoostSliderControl`, the VoiceOver words in `BoostSlider+Accessibility`.
//
// The slider is the 240-pt track and nothing else, as the WP0a seam was: the host's slider row draws the `sun.min` and
// `sun.max.fill` glyphs at its ends (DESIGN.md §5.4), and the host's value text carries "· small gain on this display"
// (DESIGN.md §5.5), so a guard's words never get it. It is one Tab stop: a host with its own focus state binds it with
// `focusBinding(_:equals:)`, never with a second `.focusable()` around it.
import Foundation
import OverbrightCore
import OverbrightPolicy
import SwiftUI

/// The level slider: dim half, Standard detent, boost half with preset ticks and the allowed-now marker.
public struct BoostSlider: View {
    /// The slider's own focus, while no host binds it.
    enum OwnFocus: Hashable { case slider }

    let level: Binding<LevelPosition>
    let top: Double
    let allowedNow: Double?
    let presets: [LevelPreset]
    let dimEnabled: Bool
    let boostHalf: BoostHalfState
    let accessibilityName: String
    let valueText: (LevelPosition) -> String
    let onCommit: (LevelPosition) -> Void
    private(set) var spokenValue: ((LevelPosition) -> String)?
    private(set) var extraRangeText: ValueText?
    private(set) var dimHalfReason: String?
    private(set) var dimmedLevel = LevelMapping.position(forDimLight: 0.25)
    /// The pointer rests on the slider from the start, so the scroll listener's anchor is in place at once (tests
    /// host the slider in a window that is never ordered in, where no pointer moves).
    private(set) var startsUnderPointer = false

    @FocusState private var ownFocus: OwnFocus?

    /// - Parameters:
    ///   - level: the display's level (−1 … 1).
    ///   - top: the light gain at the top of the boost half for this display and cap mode (`GainCeiling.sliderTop`).
    ///   - allowedNow: the light gain macOS allows now (the marker), nil when there is no reading.
    ///   - presets: the presets shown on this display (`PresetVisibility.visiblePresets`).
    ///   - dimEnabled: whether the dim half works (a transfer table or the overlay).
    ///   - boostHalf: how the boost half draws and behaves.
    ///   - accessibilityName: the display name in "Level, ‹display name›".
    ///   - valueText: the value tag of a position, exactly as shown: the canonical text (`ValueText.forLevel`, with
    ///     the host's "· small gain on this display" when Max is below ×1.3), or the guard that holds the display
    ///     (`ValueText.guarded(by:)`). The slider adds nothing to it.
    ///   - onCommit: called once when a drag or a key step ends.
    public init(level: Binding<LevelPosition>, top: Double, allowedNow: Double?, presets: [LevelPreset],
                dimEnabled: Bool, boostHalf: BoostHalfState, accessibilityName: String,
                valueText: @escaping (LevelPosition) -> String, onCommit: @escaping (LevelPosition) -> Void) {
        self.level = level
        self.top = top; self.allowedNow = allowedNow; self.presets = presets; self.dimEnabled = dimEnabled
        self.boostHalf = boostHalf; self.accessibilityName = accessibilityName
        self.valueText = valueText; self.onCommit = onCommit
    }

    /// The VoiceOver value of a position ("Bright room, 1.29 times"). Without it VoiceOver hears the spoken form of
    /// `valueText` when that is the canonical text of `ValueText.forLevel`, else `valueText` itself; a host whose
    /// value text adds anything (a suffix, nits) passes its spoken form here.
    public func spokenValue(_ text: @escaping (LevelPosition) -> String) -> BoostSlider {
        var copy = self
        copy.spokenValue = text
        return copy
    }

    /// The allowed-now marker's help tag and VoiceOver "Extra range" content (`ValueText.extraRange(allowed:peak:)`,
    /// with the display's Peak ceiling). Without it the slider says what macOS allows now, without the Peak sentence.
    public func extraRange(_ text: ValueText?) -> BoostSlider {
        var copy = self
        copy.extraRangeText = text
        return copy
    }

    /// The help tag of a disabled dim half (DESIGN.md §5.5): why the display cannot be dimmed, already localized
    /// (its verdict sentence, `VerdictText`). Shown only while `dimEnabled` is false.
    public func dimHalfReason(_ reason: String?) -> BoostSlider {
        var copy = self
        copy.dimHalfReason = reason
        return copy
    }

    /// The level of the "Dimmed" VoiceOver action (the last dim level; default 25 % of Standard light).
    public func dimmedLevel(_ level: LevelPosition) -> BoostSlider {
        var copy = self
        copy.dimmedLevel = level
        return copy
    }

    /// The slider with the pointer already resting on it (tests only, see `startsUnderPointer`).
    func underPointer() -> BoostSlider {
        var copy = self
        copy.startsUnderPointer = true
        return copy
    }

    /// The slider as one element of the host's Tab order: focus moves to it when `focus` becomes `value`, and `focus`
    /// becomes `value` when the slider takes focus. The slider stays the only focusable element (one Tab stop, one
    /// ring, its own ←, →, Home and End); without a binding (`focus` nil) it keeps its own focus. Apply it last,
    /// after the slider's other modifiers.
    @ViewBuilder
    public func focusBinding<Value: Hashable>(_ focus: FocusState<Value?>.Binding?, equals value: Value) -> some View {
        if let focus {
            BoostSliderControl(self, focus: focus, equals: value)
        } else {
            self
        }
    }

    /// The rules of this slider.
    var model: BoostSliderModel {
        BoostSliderModel(top: top, allowedNow: allowedNow, presets: presets, dimEnabled: dimEnabled, boostHalf: boostHalf)
    }

    /// The control.
    public var body: some View {
        BoostSliderControl(self, focus: $ownFocus, equals: .slider)
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
        BoostSlider(level: .constant(.standard), top: 2.587, allowedNow: nil, presets: presets, dimEnabled: false,
                    boostHalf: .inactive, accessibilityName: "Sidecar Display", valueText: text, onCommit: { _ in })
            .dimHalfReason("macOS doesn’t let apps adjust this display.")
    }
    .padding()
    .overbrightThemeRoot()
}
