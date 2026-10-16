// OverbrightDesign/Components/BoostSliderTrack.swift — the drawing of the level slider. DESIGN.md §2.1, §5.5.
// Fills and marks are drawn over the track, never in its place: the dim fill left of the detent, the warm fill right of
// it only while extra light is on screen (else the hatch), the hatch beyond the allowed-now marker and over a half that
// is off, then the preset ticks, the Standard detent, the marker and the thumb. Laid out from the leading edge with
// `.leading` alignment and `offset(x:)`, so a right-to-left layout mirrors it like a system slider.
import OverbrightCore
import SwiftUI

/// The track, fills, marks and thumb of `BoostSlider` (decorative: the slider is one accessibility element).
struct BoostSliderTrack: View {
    @Environment(\.overbright) private var theme

    /// The 240-pt track (its boost half is 120 pt).
    static let width: CGFloat = 240
    /// The thumb's diameter.
    static let thumbSize: CGFloat = 20

    let model: BoostSliderModel
    let level: LevelPosition
    let isDragging: Bool

    var body: some View {
        let width = Self.width
        let thickness = isDragging ? StrokeWidth.trackDragging : StrokeWidth.track
        let center = width / 2
        let thumbX = x(of: level)
        ZStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.color(.track)).frame(width: width, height: thickness)
                if !model.dimEnabled { hatch(from: 0, to: center, height: thickness) }
                if model.boostHalfHatched { hatch(from: center, to: width, height: thickness) }
                if level.isDim { segment(from: thumbX, to: center, height: thickness).foregroundStyle(theme.color(.dimFill)) }
                if level.isBoost && !model.boostHalfHatched {
                    if model.boostFillIsWarm {
                        let lit = model.markerLevel.map { min(thumbX, x(of: $0)) } ?? thumbX
                        segment(from: center, to: lit, height: thickness).foregroundStyle(theme.color(.boostWarm))
                    } else {
                        hatch(from: center, to: thumbX, height: thickness)
                    }
                }
                if let marker = model.markerLevel { hatch(from: x(of: marker), to: width, height: thickness) }
            }
            .frame(width: width, height: thickness)
            .clipShape(Capsule(style: .continuous))
            .animation(theme.animation(.colorShift), value: model.boostFillIsWarm)

            ForEach(model.tickLevels, id: \.self) { tick in
                mark(StrokeWidth.presetTick, at: x(of: tick), color: theme.color(.tick))
            }
            mark(StrokeWidth.detent, at: center, color: theme.color(.detentMark))
            if let marker = model.markerLevel {
                mark(StrokeWidth.allowedMarker, at: x(of: marker), color: theme.color(.allowedMarker))
            }
            Circle()
                .fill(Color.white)
                .frame(width: Self.thumbSize, height: Self.thumbSize)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                .offset(x: thumbX - Self.thumbSize / 2)
        }
        .frame(width: width, height: HitTarget.sliderThumb, alignment: .leading)
        .accessibilityHidden(true)
    }

    /// The x of `level` from the leading edge.
    private func x(of level: LevelPosition) -> CGFloat { CGFloat(BoostSliderModel.fraction(of: level)) * Self.width }

    private func segment(from a: CGFloat, to b: CGFloat, height: CGFloat) -> some View {
        Rectangle().frame(width: max(abs(b - a), 0), height: height).offset(x: min(a, b))
    }

    private func hatch(from a: CGFloat, to b: CGFloat, height: CGFloat) -> some View {
        HatchPattern()
            .stroke(theme.color(.inactiveHatch), lineWidth: StrokeWidth.hatchLine)
            .frame(width: max(abs(b - a), 0), height: height)
            .clipped()
            .offset(x: min(a, b))
    }

    private func mark(_ size: CGSize, at x: CGFloat, color: Color) -> some View {
        Rectangle().fill(color).frame(width: size.width, height: size.height).offset(x: x - size.width / 2)
    }
}
