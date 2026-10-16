// OverbrightFillLightTests/FrameGeometryTests.swift — width, rounded inner corners, the menu bar and notch band
// (ARCHITECTURE.md §10.9; DESIGN.md §11: inner corner radius min(24, width), top edge below the menu bar, reaching the
// top in a full-screen Space).
import CoreGraphics
import Testing
@testable import OverbrightFillLight

@Suite struct FrameGeometryTests {
    /// A 2560 × 1440 external display with a 30 pt menu bar (macOS 27).
    private func external(width: Double = 48, reachesTop: Bool = false) -> FrameGeometry {
        FrameGeometry(displaySize: CGSize(width: 2_560, height: 1_440), menuBarHeight: 30, safeAreaTop: 0, width: width,
                      reachesTop: reachesTop)
    }

    @Test func widthInsetsTheInnerEdgeOnEverySide() {
        let g = external()
        #expect(g.bounds == CGRect(x: 0, y: 0, width: 2_560, height: 1_440))
        #expect(g.topInset == 30)
        #expect(g.outer == CGRect(x: 0, y: 0, width: 2_560, height: 1_410))
        #expect(g.inner == CGRect(x: 48, y: 48, width: 2_464, height: 1_314))
        #expect(g.width == 48)
        #expect(g.isLit(CGPoint(x: 10, y: 700)))            // left band
        #expect(g.isLit(CGPoint(x: 2_550, y: 700)))         // right band
        #expect(g.isLit(CGPoint(x: 1_280, y: 10)))          // bottom band (over the Dock: click-through)
        #expect(g.isLit(CGPoint(x: 1_280, y: 1_400)))       // top band, just below the menu bar
        #expect(!g.isLit(CGPoint(x: 1_280, y: 700)))        // the middle stays dark (even-odd)
        #expect(!g.isLit(CGPoint(x: 1_280, y: 1_425)))      // the menu bar stays clear
        #expect(!g.isLit(CGPoint(x: 49, y: 700)))           // just inside the inner edge
    }

    @Test func widthIsClampedToTheSettingsRange() {
        #expect(external(width: 4).width == 16)
        #expect(external(width: 500).width == 120)
        #expect(external(width: .nan).width == 48)
        #expect(external(width: 120).inner == CGRect(x: 120, y: 120, width: 2_320, height: 1_170))
    }

    @Test func innerCornersAreRoundedWithRadiusMin24Width() {
        #expect(external(width: 48).innerCornerRadius == 24)
        #expect(external(width: 16).innerCornerRadius == 16)
        #expect(external(width: 120).innerCornerRadius == 24)
        let g = external(width: 48)
        let corner = CGPoint(x: g.inner.minX + 3, y: g.inner.minY + 3)
        #expect(g.isLit(corner))                                                         // the rounding is lit
        #expect(!g.isLit(CGPoint(x: g.inner.minX + 24, y: g.inner.minY + 24)))            // the arc's centre is not
        #expect(!g.isLit(CGPoint(x: g.inner.midX, y: g.inner.minY + 3)))                  // a straight edge is square
        #expect(g.isLit(CGPoint(x: g.inner.maxX - 3, y: g.inner.maxY - 3)))               // every corner, top right too
        #expect(!g.isLit(CGPoint(x: g.inner.maxX - 3, y: g.inner.midY)))
    }

    @Test func outerCornersStaySquare() {
        let g = external()
        #expect(g.isLit(CGPoint(x: 0.5, y: 0.5)))
        #expect(g.isLit(CGPoint(x: 2_559.5, y: 1_409.5)))
    }

    @Test func notchBandStaysClearEvenWhenTheMenuBarHides() {
        // 16" built-in: 1728 × 1117 pt, notch band 32 pt; menu bar auto-hidden (visible frame reaches the top).
        let hidden = FrameGeometry(displaySize: CGSize(width: 1_728, height: 1_117), menuBarHeight: 0, safeAreaTop: 32,
                                   width: 48, reachesTop: false)
        #expect(hidden.topInset == 32)
        #expect(!hidden.isLit(CGPoint(x: 100, y: 1_117 - 10)))
        #expect(hidden.isLit(CGPoint(x: 100, y: 1_117 - 33)))
        // Menu bar taller than the notch band: the larger one wins.
        let shown = FrameGeometry(displaySize: CGSize(width: 1_728, height: 1_117), menuBarHeight: 37, safeAreaTop: 32,
                                  width: 48, reachesTop: false)
        #expect(shown.topInset == 37)
        #expect(!shown.isLit(CGPoint(x: 100, y: 1_117 - 35)))
        #expect(shown.isLit(CGPoint(x: 100, y: 1_117 - 38)))
    }

    @Test func anAutoHiddenMenuBarKeepsItsBandOutsideAFullScreenSpace() {
        // `frame.maxY − visibleFrame.maxY` is 0 while an auto-hidden bar is out of sight; the frame sits above the menu
        // bar's level, so the band stays clear on a display that shows the bar.
        #expect(FrameGeometry.menuBarBand(reported: 30, showsMenuBar: true, barHeight: 0) == 30)
        #expect(FrameGeometry.menuBarBand(reported: 37, showsMenuBar: true, barHeight: 24) == 37)
        #expect(FrameGeometry.menuBarBand(reported: 0, showsMenuBar: true, barHeight: 0) == 30)
        #expect(FrameGeometry.menuBarBand(reported: 0, showsMenuBar: true, barHeight: 24) == 30)
        #expect(FrameGeometry.menuBarBand(reported: 0, showsMenuBar: true, barHeight: 37) == 37)
        #expect(FrameGeometry.menuBarBand(reported: 0, showsMenuBar: true, barHeight: .nan) == 30)
        #expect(FrameGeometry.menuBarBand(reported: .nan, showsMenuBar: true, barHeight: 0) == 30)
        // A display without a menu bar (displays share one Space): nothing to keep clear.
        #expect(FrameGeometry.menuBarBand(reported: 0, showsMenuBar: false, barHeight: 30) == 0)
        let band = FrameGeometry.menuBarBand(reported: 0, showsMenuBar: true, barHeight: 0)
        let hidden = FrameGeometry(displaySize: CGSize(width: 2_560, height: 1_440), menuBarHeight: band,
                                   safeAreaTop: 0, width: 48, reachesTop: false)
        #expect(hidden.topInset == 30)
        #expect(!hidden.isLit(CGPoint(x: 1_280, y: 1_425)))      // where the bar slides in
        let fullScreen = FrameGeometry(displaySize: CGSize(width: 2_560, height: 1_440), menuBarHeight: band,
                                       safeAreaTop: 0, width: 48, reachesTop: true)
        #expect(fullScreen.topInset == 0)
    }

    @Test func fullScreenSpaceReachesTheTop() {
        let g = FrameGeometry(displaySize: CGSize(width: 1_728, height: 1_117), menuBarHeight: 37, safeAreaTop: 32,
                              width: 48, reachesTop: true)
        #expect(g.topInset == 0)
        #expect(g.outer == g.bounds)
        #expect(g.isLit(CGPoint(x: 100, y: 1_116)))
        #expect(external(reachesTop: true).isLit(CGPoint(x: 1_280, y: 1_435)))
    }

    @Test func tinyDisplayKeepsAnInnerRectangleAndAValidRadius() {
        // A band wider than half the display would swallow the inner edge (and CGPath traps on a radius larger than
        // half the rectangle): the width shrinks to fit, the radius to half the inner rectangle.
        let g = FrameGeometry(displaySize: CGSize(width: 100, height: 60), menuBarHeight: 0, safeAreaTop: 0, width: 120,
                              reachesTop: false)
        #expect(g.width == 29)
        #expect(g.inner.height == 2)
        #expect(g.innerCornerRadius == 1)
        #expect(!g.isLit(CGPoint(x: 50, y: 30)))
        #expect(g.isLit(CGPoint(x: 5, y: 30)))
        let empty = FrameGeometry(displaySize: .zero, menuBarHeight: 30, safeAreaTop: 0, width: 48, reachesTop: false)
        #expect(empty.width == 0)
        #expect(!empty.isLit(.zero))
    }

    @Test func menuBarBandNeverTakesMoreThanHalfTheDisplay() {
        let g = FrameGeometry(displaySize: CGSize(width: 800, height: 100), menuBarHeight: 300, safeAreaTop: 0, width: 16,
                              reachesTop: false)
        #expect(g.topInset == 50)
        #expect(g.outer.height == 50)
    }
}
