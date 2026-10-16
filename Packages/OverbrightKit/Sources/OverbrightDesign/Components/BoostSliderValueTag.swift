// OverbrightDesign/Components/BoostSliderValueTag.swift — the level slider's value tag. DESIGN.md §5.5 (value tag),
// §2.2 (`valueTag`); ARCHITECTURE.md §8.8 (the `valueTag` width rule: at most the 240-pt track, a "small gain" suffix
// may wrap). A capsule 6 pt above the thumb, centred on it and kept inside the track: near either end it shifts inward
// the way a system slider's value tip does, so the panel never clips it at Max or at the dim floor.
import SwiftUI

/// The capsule over the thumb with the value text (decorative: VoiceOver hears the slider's value instead).
struct BoostSliderValueTag: View {
    @Environment(\.overbright) private var theme

    /// The value text ("Bright room · ×1.29", or the guard that holds the display).
    let text: String
    /// The thumb's centre from the track's leading edge.
    let thumbX: CGFloat

    /// Laid over the track (`.overlay(alignment: .topLeading)`), which proposes its own width: longer text wraps.
    var body: some View {
        let lift = Space.s - (HitTarget.sliderThumb - BoostSliderTrack.thumbSize) / 2
        let (x, trackWidth) = (thumbX, BoostSliderTrack.width)
        Text(verbatim: text)
            .font(OverbrightFont.valueTag.font)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xxs)
            .background(theme.color(.panelBackground), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .alignmentGuide(.leading) { d in
                d.width / 2 - Self.center(thumbX: x, tagWidth: d.width, trackWidth: trackWidth)
            }
            .alignmentGuide(.top) { d in d.height + lift }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The tag's centre for a thumb at `thumbX`: over the thumb, but never closer to an end of the track than half
    /// the tag's width (a tag as wide as the track sits in its middle).
    nonisolated static func center(thumbX: CGFloat, tagWidth: CGFloat, trackWidth: CGFloat) -> CGFloat {
        let half = tagWidth / 2
        guard tagWidth < trackWidth else { return trackWidth / 2 }
        return min(max(thumbX, half), trackWidth - half)
    }
}
