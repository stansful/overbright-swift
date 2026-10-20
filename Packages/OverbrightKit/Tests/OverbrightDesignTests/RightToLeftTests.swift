// OverbrightDesignTests/RightToLeftTests.swift — the right-to-left rules (Theme/RightToLeft.swift; DESIGN.md §5.5 "Right
// to left", §16): physical input converted to the layout, names isolated inside sentences, and the slider mirrored
// like a system slider (dim on the right, boost on the left; the end glyphs are its row's). Ported in part from Cranny's
// RightToLeftTests (the owner's MIT code).
import AppKit
import OverbrightCore
import SwiftUI
import Testing
@testable import OverbrightDesign

@Suite struct RightToLeftTests {
    @Test func physicalTravelAlongTheLayout() {
        #expect(LayoutDirection.leftToRight.alongLayout(12) == 12)
        #expect(LayoutDirection.rightToLeft.alongLayout(12) == -12)
        #expect(LayoutDirection.rightToLeft.alongLayout(LayoutDirection.rightToLeft.alongLayout(3)) == 3)
    }

    /// A press 60 pt from the left of the 240-pt track is a quarter from the dim end in English and three quarters
    /// from it in Arabic, where the dim end is on the right.
    @Test func fractionCountsFromTheLeadingEdge() {
        #expect(LayoutDirection.leftToRight.fraction(atPhysicalX: 60, width: 240) == 0.25)
        #expect(LayoutDirection.rightToLeft.fraction(atPhysicalX: 60, width: 240) == 0.75)
        #expect(LayoutDirection.rightToLeft.fraction(atPhysicalX: -8, width: 240) == 1)
        #expect(LayoutDirection.leftToRight.fraction(atPhysicalX: 500, width: 240) == 1)
        #expect(LayoutDirection.leftToRight.fraction(atPhysicalX: 5, width: 0) == 1)
    }

    /// ← and → move the thumb toward the side they point at: in a mirrored slider ← raises the level.
    @Test func arrowsGoTheWayTheyPoint() {
        #expect(BoostSlider.key(for: .rightArrow, option: false, direction: .leftToRight) == .stepTowardBoost)
        #expect(BoostSlider.key(for: .leftArrow, option: false, direction: .leftToRight) == .stepTowardDim)
        #expect(BoostSlider.key(for: .leftArrow, option: false, direction: .rightToLeft) == .stepTowardBoost)
        #expect(BoostSlider.key(for: .rightArrow, option: false, direction: .rightToLeft) == .stepTowardDim)
        #expect(BoostSlider.key(for: .leftArrow, option: true, direction: .rightToLeft) == .nextStop)
        #expect(LayoutDirection.rightToLeft.step(for: .upArrow) == nil)
    }

    @Test func isolationWrapsOnceAndLeavesEmptyTextAlone() {
        #expect("MPG322UX OLED".overbrightIsolated == "\u{2068}MPG322UX OLED\u{2069}")
        #expect("x".overbrightIsolated.overbrightIsolated == "x".overbrightIsolated)
        #expect("".overbrightIsolated.isEmpty)
        let font = NSFont.systemFont(ofSize: 13)
        func width(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
        #expect(abs(width("Built-in Display".overbrightIsolated) - width("Built-in Display")) < 0.01)
    }

    /// Names inside chips and banners are isolated, so a Hebrew app name cannot reorder an English sentence.
    @Test func namesInSentencesAreIsolated() throws {
        let app = ConflictingApp(entryID: "x", severity: .gammaWriter, bundleID: nil, processID: 1, displayName: "צבעים")
        let banner = BannerModel.make(.conflict(app), displayNames: [:], in: english)
        #expect(banner.sentence.contains("\u{2068}צבעים\u{2069}"))
        let chip = try #require(ChipModel.make(reason: .pausedApp(bundleID: "com.example.player"), phase: .idle, failedTries: 0,
                                                context: ChipContext(appName: "نافذة", language: english)))
        #expect(chip.text.contains("\u{2068}نافذة\u{2069}"))
    }
}

/// The slider drawn left to right and right to left.
@MainActor @Suite struct RightToLeftSliderTests {
    private static let warm = OverbrightColor.boostWarm(dark: false, highContrast: false)

    private func slider(_ level: Double, boostHalf: BoostHalfState = .active) -> some View {
        BoostSlider(level: .constant(LevelPosition(level)), top: 1.667, allowedNow: nil,
                    presets: [.indoor, .brightRoom, .sunlight, .max], dimEnabled: true, boostHalf: boostHalf,
                    accessibilityName: "Built-in Display", valueText: { _ in "" }, onCommit: { _ in })
    }

    /// The warm fill runs from the detent toward the boost end: right of centre in English, left of it in Arabic. At
    /// Max it shows up to the thumb, whose 20-pt disc ends at the track's end (30 … 270 pt on a 300-pt canvas).
    @Test func theBoostFillMirrors() throws {
        let size = CGSize(width: 300, height: 40)
        let ltr = try render(slider(1), size: size)
        let rtl = try render(slider(1), size: size, direction: .rightToLeft)
        let ltrWarm = try #require(ltr.xRange { $0.isClose(to: Self.warm) })
        let rtlWarm = try #require(rtl.xRange { $0.isClose(to: Self.warm) })
        #expect(ltrWarm.lowerBound >= 145 && ltrWarm.upperBound > 245, "left to right: \(ltrWarm)")
        #expect(rtlWarm.upperBound <= 155 && rtlWarm.lowerBound < 55, "right to left: \(rtlWarm)")
    }

    /// The slider draws no end glyphs in either direction (the card's slider row draws `sun.min` and `sun.max.fill`
    /// and mirrors them with its HStack, DESIGN.md §5.4): at Standard the only dark marks are the preset ticks on the
    /// boost half of the 240-pt track (30 … 270 pt on a 300-pt canvas), right of centre in English, left in Arabic.
    @Test func theSliderLeavesTheEndGlyphsToItsRow() throws {
        let size = CGSize(width: 300, height: 40)
        func darkInk(_ p: RenderedPixels.Pixel) -> Bool { p.r < 0.6 && p.g < 0.6 && p.b < 0.6 && p.a > 0.5 }
        let ltr = try #require(try render(slider(0), size: size).xRange(of: darkInk), "the ticks are drawn")
        let rtl = try #require(try render(slider(0), size: size, direction: .rightToLeft).xRange(of: darkInk))
        #expect(ltr.lowerBound > 150 && ltr.upperBound <= 270.5, "left to right: ink at \(ltr)")
        #expect(rtl.lowerBound >= 29.5 && rtl.upperBound < 150, "right to left: ink at \(rtl)")
    }
}
