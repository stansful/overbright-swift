// OverbrightDesignTests/RightToLeftTests.swift — the right-to-left rules (Theme/RightToLeft.swift; DESIGN.md §5.5 "Right
// to left", §16): physical input converted to the layout, names isolated inside sentences, and the slider mirrored
// like a system slider (dim on the right, boost on the left, glyphs swapped). Ported in part from Cranny's
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
        #expect(LayoutDirection.rightToLeft.step(physical: -1) == 1)
    }

    @Test func isolationWrapsOnceAndLeavesEmptyTextAlone() {
        #expect("MPG322UX OLED".overbrightIsolated == "\u{2068}MPG322UX OLED\u{2069}")
        #expect("x".overbrightIsolated.overbrightIsolated == "x".overbrightIsolated)
        #expect("".overbrightIsolated.isEmpty)
        let font = NSFont.systemFont(ofSize: 13)
        func width(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
        #expect(abs(width("Built-in Display".overbrightIsolated) - width("Built-in Display")) < 0.01)
    }

    @Test func aTextReadsInTheDirectionOfItsFirstLetter() {
        #expect(BidiIsolation.direction(of: "Built-in Display") == .leftToRight)
        #expect(BidiIsolation.direction(of: "شاشة مدمجة") == .rightToLeft)
        #expect(BidiIsolation.direction(of: "מסך") == .rightToLeft)
        #expect(BidiIsolation.direction(of: "1.29") == nil)
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

    /// The warm fill runs from the detent toward the boost end: right of centre in English, left of it in Arabic.
    @Test func theBoostFillMirrors() throws {
        let size = CGSize(width: 300, height: 40)
        let ltr = try render(slider(1), size: size)
        let rtl = try render(slider(1), size: size, direction: .rightToLeft)
        let ltrWarm = try #require(ltr.xRange { $0.isClose(to: Self.warm) })
        let rtlWarm = try #require(rtl.xRange { $0.isClose(to: Self.warm) })
        #expect(ltrWarm.lowerBound >= 145 && ltrWarm.upperBound > 250, "left to right: \(ltrWarm)")
        #expect(rtlWarm.upperBound <= 155 && rtlWarm.lowerBound < 50, "right to left: \(rtlWarm)")
    }

    /// The glyphs swap: the small sun is at the dim end, which is on the right in Arabic.
    @Test func theEndGlyphsSwap() throws {
        let size = CGSize(width: 300, height: 40)
        func darkInk(_ p: RenderedPixels.Pixel) -> Bool { p.r < 0.6 && p.g < 0.6 && p.b < 0.6 && p.a > 0.5 }
        // At Standard nothing is filled: the only dark ink at the far edges is the glyphs.
        let ltr = try render(slider(0), size: size)
        let rtl = try render(slider(0), size: size, direction: .rightToLeft)
        let ltrLeft = ltr.count { darkInk($0) }
        #expect(ltrLeft > 0)
        let leftGlyphLTR = try #require(ltr.xRange(of: darkInk))
        let leftGlyphRTL = try #require(rtl.xRange(of: darkInk))
        #expect(abs(leftGlyphLTR.lowerBound - leftGlyphRTL.lowerBound) < 2, "both have a glyph at the left edge")
        // The small sun has less ink than the filled big sun; mirrored, the ink at each edge swaps.
        func ink(_ pixels: RenderedPixels, x range: ClosedRange<Int>) -> Int {
            var n = 0
            for y in 0..<pixels.height { for x in range where darkInk(pixels.pixel(x: x, y: y)) { n += 1 } }
            return n
        }
        let leftLTR = ink(ltr, x: 0...60), rightLTR = ink(ltr, x: (ltr.width - 60)...(ltr.width - 1))
        let leftRTL = ink(rtl, x: 0...60), rightRTL = ink(rtl, x: (rtl.width - 60)...(rtl.width - 1))
        #expect(leftLTR < rightLTR, "sun.min left, sun.max.fill right: \(leftLTR) vs \(rightLTR)")
        #expect(leftRTL > rightRTL, "mirrored: \(leftRTL) vs \(rightRTL)")
    }
}
