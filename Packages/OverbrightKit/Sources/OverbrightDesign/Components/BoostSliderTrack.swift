// OverbrightDesign/Components/BoostSliderTrack.swift — the drawing of the level slider. DESIGN.md §2.1, §5.5, §15.
// Fills and marks are drawn over the track, never in its place: the dim fill left of the detent, the warm fill right of
// it only while extra light is on screen (else the hatch), the hatch beyond the allowed-now marker and over a half that
// is off, then the preset ticks, the Standard detent, the thumb, and the allowed-now marker on top: taller than the
// thumb, with a halo, so it shows where the thumb rests on it. The thumb's centre travels the track inset by its radius
// at both ends, as a system slider's does, so at Max and at the dim floor it stays over the track instead of running
// into the end glyphs 6 pt beyond it; ticks, fills and the marker follow the same travel. Under Increase Contrast the
// white thumb takes a 1-pt ring (`thumbRing`), since the opaque white card would swallow it. Laid out from the leading
// edge with `.leading` alignment and `offset(x:)`, so a right-to-left layout mirrors it like a system slider.
import OverbrightCore
import SwiftUI

/// The track, fills, marks and thumb of `BoostSlider` (decorative: the slider is one accessibility element).
struct BoostSliderTrack: View {
    @Environment(\.overbright) private var theme

    /// The 240-pt track (its boost half is 120 pt).
    static let width: CGFloat = 240
    /// The thumb's diameter.
    static let thumbSize: CGFloat = 20
    /// How far the thumb's centre travels: the track less the thumb's radius at each end.
    static let travel: CGFloat = width - thumbSize

    /// The x of `level` from the leading edge: where the thumb's centre, a tick, the detent or the marker stands
    /// (Standard at the centre of the track, the dim floor and Max a thumb's radius in from its ends).
    static func x(of level: LevelPosition) -> CGFloat {
        thumbSize / 2 + CGFloat(BoostSliderModel.fraction(of: level)) * travel
    }

    /// The fraction of the thumb's travel (0 at the dim end, 1 at the boost end) under physical `x`, a gesture's
    /// location from the track's left edge; past either end of the travel it is that end.
    static func fraction(atPhysicalX x: CGFloat, direction: LayoutDirection) -> Double {
        direction.fraction(atPhysicalX: x - thumbSize / 2, width: travel)
    }

    let model: BoostSliderModel
    let level: LevelPosition
    let isDragging: Bool

    var body: some View {
        let width = Self.width
        let thickness = isDragging ? StrokeWidth.trackDragging : StrokeWidth.track
        let center = Self.x(of: .standard)
        let thumbX = Self.x(of: level)
        ZStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.color(.track)).frame(width: width, height: thickness)
                if !model.dimEnabled { hatch(from: 0, to: center, height: thickness) }
                if model.boostHalfHatched { hatch(from: center, to: width, height: thickness) }
                if level.isDim { segment(from: thumbX, to: center, height: thickness).foregroundStyle(theme.color(.dimFill)) }
                if level.isBoost && !model.boostHalfHatched {
                    if model.boostFillIsWarm {
                        let lit = model.markerLevel.map { min(thumbX, Self.x(of: $0)) } ?? thumbX
                        segment(from: center, to: lit, height: thickness).foregroundStyle(theme.color(.boostWarm))
                    } else {
                        hatch(from: center, to: thumbX, height: thickness)
                    }
                }
                if let marker = model.markerLevel { hatch(from: Self.x(of: marker), to: width, height: thickness) }
            }
            .frame(width: width, height: thickness)
            .clipShape(Capsule(style: .continuous))
            .animation(theme.animation(.colorShift), value: model.boostFillIsWarm)

            ForEach(model.tickLevels, id: \.self) { tick in
                mark(StrokeWidth.presetTick, at: Self.x(of: tick), color: theme.color(.tick))
            }
            mark(StrokeWidth.detent, at: center, color: theme.color(.detentMark))
            thumb.offset(x: thumbX - Self.thumbSize / 2)
            if let marker = model.markerLevel { allowedMarker(at: Self.x(of: marker)) }
        }
        .frame(width: width, height: HitTarget.sliderThumb, alignment: .leading)
        .accessibilityHidden(true)
    }

    /// A 20-pt white circle with the system shadow (and its ring under Increase Contrast); on macOS 26+ it takes
    /// glass while dragged (the system behaviour of transient controls), never under Reduce Transparency or Increase
    /// Contrast.
    @ViewBuilder private var thumb: some View {
        let circle = Circle()
            .fill(theme.color(.thumb))
            .overlay(Circle().strokeBorder(theme.color(.thumbRing), lineWidth: StrokeWidth.regular))
            .frame(width: Self.thumbSize, height: Self.thumbSize)
            .overbrightShadow(.thumb)
        if #available(macOS 26, *), isDragging, theme.usesGlass {
            circle.glassEffect(.regular, in: Circle())
        } else {
            circle
        }
    }

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

    /// The allowed-now marker at `x`: `allowedMarker` in a halo of the panel's background, over the thumb.
    private func allowedMarker(at x: CGFloat) -> some View {
        let size = StrokeWidth.allowedMarker, halo = StrokeWidth.allowedMarkerHalo
        return Rectangle().fill(theme.color(.allowedMarker))
            .frame(width: size.width, height: size.height)
            .padding(halo)
            .background(theme.color(.panelBackground))
            .offset(x: x - size.width / 2 - halo)
    }
}
