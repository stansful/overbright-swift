// OverbrightDesignTests/BoostSliderDrawingTests.swift — where the slider's thumb and allowed-now marker land, read from
// rendered pixels (DESIGN.md §0 #16, §5.4, §5.5, §15): the marker shows even where the thumb rests on it (it is drawn
// over the thumb, taller than it, with a halo), the thumb stays over the track at Max and at the dim floor in either
// direction (its travel is inset by its radius), and under Increase Contrast the white thumb has a ring on the opaque
// white card. The slider is rendered off screen; nothing is ordered in.
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct BoostSliderDrawingTests {
    /// The canvas: the 240-pt track centred in 300 pt (it starts 30 pt in), the 28-pt control centred in 40 pt (its top
    /// is 6 pt down, so the 20-pt thumb spans y 10…30).
    private static let size = CGSize(width: 300, height: 40)
    private static let trackStart: CGFloat = 30, thumbTop: CGFloat = 10
    private static let top = 2.587

    private func slider(_ level: Double, allowed: Double? = nil) -> BoostSlider {
        BoostSlider(level: .constant(LevelPosition(level)), top: Self.top, allowedNow: allowed,
                    presets: [.indoor, .brightRoom, .sunlight, .max], dimEnabled: true, boostHalf: .active,
                    accessibilityName: "Built-in Display", valueText: { _ in "" }, onCommit: { _ in })
    }

    private func srgb(_ pixel: RenderedPixels.Pixel) -> SRGBA { SRGBA(red: pixel.r, green: pixel.g, blue: pixel.b) }

    /// The pixels in the rectangle `x` × `y` (points) whose contrast with `color` is at least `ratio`.
    private func count(in pixels: RenderedPixels, x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>,
                       against color: SRGBA, ratio: Double = 3) -> Int {
        var n = 0
        for py in Int(y.lowerBound * 2)..<Int(y.upperBound * 2) {
            for px in Int(x.lowerBound * 2)..<Int(x.upperBound * 2)
            where srgb(pixels.pixel(x: px, y: py)).contrast(with: color) >= ratio { n += 1 }
        }
        return n
    }

    /// macOS allows a little less than asked (limited-by-macos): the marker sits 2 pt from the thumb's centre, under
    /// its disc. It used to be drawn first and 10 pt tall, so the 20-pt thumb hid it; now it reads over the white thumb
    /// in either appearance (dark ink in Light, the dark halo around near-white ink in Dark) and above the thumb.
    @Test(arguments: [ColorScheme.light, .dark])
    func theMarkerShowsWhereTheThumbRestsOnIt(scheme: ColorScheme) throws {
        let allowed = pow(Self.top, 0.88)
        let markerX = Self.trackStart + BoostSliderTrack.x(of: LevelPosition(0.88))
        let thumbX = Self.trackStart + BoostSliderTrack.x(of: LevelPosition(0.9))
        #expect(abs(markerX - thumbX) < BoostSliderTrack.thumbSize / 2 - 4, "the marker is under the thumb's disc")
        let background = scheme == .dark ? SRGBA(white: 0.12) : .white
        let pixels = try render(slider(0.9, allowed: allowed), size: Self.size, scheme: scheme,
                                background: background.color)
        let onThumb = count(in: pixels, x: markerX - 2...markerX + 2, y: Self.thumbTop + 3...Self.thumbTop + 17,
                            against: .white)
        #expect(onThumb >= 40, "\(scheme): \(onThumb) marker pixels read over the white thumb")
        let above = count(in: pixels, x: markerX - 1...markerX + 1, y: Self.thumbTop - 2...Self.thumbTop - 1,
                          against: background)
        #expect(above >= 4, "\(scheme): the marker stands above the thumb (\(above) pixels)")
    }

    /// At Max and at the dim floor the white thumb ends at the track's end (30…270 on the canvas), in either direction:
    /// it used to overhang by its radius, into the end glyph 6 pt beyond.
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func theThumbStaysOverTheTrackAtBothEnds(direction: LayoutDirection) throws {
        let grey = Color(white: 0.5)
        for level in [-1.0, 1] {
            let pixels = try render(slider(level), size: Self.size, direction: direction, background: grey)
            let thumb = try #require(pixels.xRange { $0.isClose(to: .white, tolerance: 0.03) }, "\(level) \(direction)")
            #expect(thumb.lowerBound >= Self.trackStart - 0.5 && thumb.upperBound <= Self.trackStart + 240.5,
                    "\(level) \(direction): the thumb spans \(thumb)")
            #expect(thumb.upperBound - thumb.lowerBound >= BoostSliderTrack.thumbSize - 2, "the whole thumb is drawn")
        }
    }

    /// Under Increase Contrast the card is opaque white, and so is the thumb: a 1-pt `labelColor` ring keeps it at
    /// least 3:1 apart (WCAG 1.4.11); without Increase Contrast the system shadow does that and there is no ring.
    @Test func increaseContrastRingsTheThumb() throws {
        let thumbX = Self.trackStart + BoostSliderTrack.x(of: .standard)
        let edge = (x: thumbX - 1...thumbX + 1, y: Self.thumbTop...Self.thumbTop + 1)
        let contrast = try render(slider(0), size: Self.size, theme: OverbrightTheme(increaseContrast: true))
        #expect(count(in: contrast, x: edge.x, y: edge.y, against: .white) >= 2, "a ring at the thumb's top edge")
        let standard = try render(slider(0), size: Self.size)
        #expect(count(in: standard, x: edge.x, y: edge.y, against: .white) == 0, "no ring without Increase Contrast")
        for scheme in [ColorScheme.light, .dark] {
            let card = OverbrightColor.card.resolved(palette: .highContrast, scheme: scheme)
                .over(OverbrightColor.panelBackground.resolved(palette: .highContrast, scheme: scheme))
            let ring = OverbrightColor.thumbRing.resolved(palette: .highContrast, scheme: scheme).over(card)
            // In Light the ring carries the thumb's edge; in Dark the white thumb stands off the dark card by itself.
            #expect(max(ring.contrast(with: card), SRGBA.white.contrast(with: card)) >= 3,
                    "\(scheme): the thumb's edge stands 3:1 off the card")
            if scheme == .light { #expect(ring.contrast(with: .white) >= 3, "the ring stands 3:1 off the white thumb") }
            #expect(OverbrightColor.thumbRing.resolved(palette: .standard, scheme: scheme).alpha == 0)
        }
    }
}
