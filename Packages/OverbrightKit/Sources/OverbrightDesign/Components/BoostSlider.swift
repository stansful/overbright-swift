// OverbrightDesign/Components/BoostSlider.swift — the one per-display level control. DESIGN.md §5.5, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed (the allowed-now marker is part of the
// slider); WP9 builds the real control (detent, ticks, fills over the track, hatch, value tag, snapping with haptics,
// steps in stops, the adjustable VoiceOver element, RTL). The WP0a body is a plain system slider.
import OverbrightCore
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

    /// WP0a placeholder: a system slider over −1 … 1.
    public var body: some View {
        Slider(value: Binding(get: { level.value }, set: { level = LevelPosition($0) }),
               in: (dimEnabled ? -1 : 0)...(boostEnabled ? 1 : 0)) { editing in
            if !editing { onCommit(level) }
        }
        .labelsHidden()
        .accessibilityLabel(Text(verbatim: accessibilityName))
        .accessibilityValue(Text(verbatim: valueText(level)))
    }

    private var boostEnabled: Bool {
        if case .unavailable = boostHalf { return false }
        return top > 1
    }
}
