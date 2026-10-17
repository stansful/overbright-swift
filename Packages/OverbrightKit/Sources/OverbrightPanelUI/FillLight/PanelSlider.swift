// OverbrightPanelUI/FillLight/PanelSlider.swift — the Fill Light card's Brightness and Warmth sliders, drawn in shapes
// like the level slider's track (DESIGN.md §2.1 `track`, `thumb`, `thumbRing`; §5.3; §15): a capsule track, the
// accent colour up to the thumb as a system slider fills, and a white thumb with the system shadow (and its ring under
// Increase Contrast), at the small control size the card used (14 pt). The thumb's centre travels the track inset by
// its radius at both ends, as a system slider's does. Not the system `Slider`: on macOS 26 and later its Liquid Glass
// knob renders with in-process Metal on every showing, a ≈ 270 MB GPU-driver charge for ≈ 1 s each time the panel
// opens while Fill Light is on (DESIGN.md §17). One accessibility element: VoiceOver reads the label and the card's
// value text and adjusts by the card's keyboard step; the panel's focus wrapper (`panelFocus`) takes ← and →. A
// pointer press or drag sets the value under it (mirrored right to left: input stays physical, `RightToLeft.swift`).
import OverbrightDesign
import SwiftUI

/// A compact horizontal slider over `range`, drawn without system controls.
struct PanelSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// One VoiceOver increment (the card's ← / → step).
    let step: Double
    /// VoiceOver's label.
    let label: String
    /// VoiceOver's value ("80 %", "5,100 K").
    let valueText: String
    @Environment(\.overbright) private var theme
    @Environment(\.layoutDirection) private var direction

    /// The control's height: a small system slider's.
    static let height: CGFloat = 14
    /// The thumb's diameter.
    static let thumbSize: CGFloat = 14

    var body: some View {
        Capsule(style: .continuous)
            .fill(theme.color(.track))
            .frame(height: StrokeWidth.track)
            .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let thumbX = Self.x(of: Self.fraction(of: value, in: range), width: width)
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: max(thumbX, 0), height: StrokeWidth.track)
                        thumb.offset(x: thumbX - Self.thumbSize / 2)
                    }
                    .frame(width: width, height: proxy.size.height, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged { drag in
                        value = Self.value(atPhysicalX: drag.location.x, width: width, in: range, direction: direction)
                    })
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(verbatim: valueText))
            .accessibilityAdjustableAction { adjustment in
                guard let adjusted = Self.adjusted(value, by: adjustment, in: range, step: step) else { return }
                value = adjusted
            }
    }

    /// A white circle with the system thumb's shadow, and a ring under Increase Contrast (the opaque card would
    /// swallow it), as the level slider's thumb.
    private var thumb: some View {
        Circle()
            .fill(theme.color(.thumb))
            .overlay(Circle().strokeBorder(theme.color(.thumbRing), lineWidth: StrokeWidth.regular))
            .frame(width: Self.thumbSize, height: Self.thumbSize)
            .overbrightShadow(.thumb)
    }

    /// VoiceOver's increment or decrement of `value`: one `step`, kept in `range` (nil for anything else).
    static func adjusted(_ value: Double, by adjustment: AccessibilityAdjustmentDirection, in range: ClosedRange<Double>,
                         step: Double) -> Double? {
        switch adjustment {
        case .increment: FillLightCard.stepped(value, in: range, by: step, towardEnd: true)
        case .decrement: FillLightCard.stepped(value, in: range, by: step, towardEnd: false)
        @unknown default: nil
        }
    }

    // MARK: Geometry

    /// Where `value` sits in `range`, 0 at its start and 1 at its end (clamped).
    static func fraction(of value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// The x of the thumb's centre at `fraction` from the leading edge of a `width`-wide track: a thumb's radius in
    /// from either end.
    static func x(of fraction: Double, width: CGFloat) -> CGFloat {
        thumbSize / 2 + CGFloat(fraction) * max(width - thumbSize, 0)
    }

    /// The value under physical `x` (a gesture's location from the track's left edge) of a `width`-wide track:
    /// leading to trailing in the layout's direction, the ends a thumb's radius in, clamped to `range`.
    static func value(atPhysicalX x: CGFloat, width: CGFloat, in range: ClosedRange<Double>,
                      direction: LayoutDirection) -> Double {
        let fraction = direction.fraction(atPhysicalX: x - thumbSize / 2, width: max(width - thumbSize, 1))
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}

#Preview("Fill Light slider") {
    @Previewable @State var value = 0.8
    PanelSlider(value: $value, range: FillLightCard.brightnessRange, step: FillLightCard.brightnessStep,
                label: PanelText.brightness, valueText: FillLightCard.percentText(value))
        .frame(width: 160)
        .padding()
        .overbrightThemeRoot()
}
