// OverbrightOnboarding/Steps/StepMetrics.swift — the steps' own layout measurements (DESIGN.md §8), so no step writes a
// literal frame size (ARCHITECTURE.md §9.2 rule 3). Fonts are system text styles, colours, spacing and radii are Design's
// tokens (DESIGN.md §2.0 rule 1); the window's measurements are the chrome's `WelcomeMetrics`.
import CoreGraphics
import OverbrightDesign

/// Frame sizes inside the Welcome steps.
nonisolated enum StepMetrics {
    /// A page keeps its content below the hidden title bar and its window buttons (32 pt on macOS 27).
    static let titleBarInset = Space.huge
    /// The stage's bottom inset.
    static let stageBottomInset = Space.xl
    /// The height the stage's content gets.
    static let stageContentHeight = WelcomeMetrics.stageHeight - titleBarInset - stageBottomInset
    /// The widest a compact stage's glyph row may be: centred, it stays clear of the window buttons at the leading edge.
    static let compactStageContentWidth: CGFloat = 320
    /// Step 1's before/after card: the stage's content height, at most this wide.
    static let cardWidth: CGFloat = 448
    /// The frame of the illustration of a step without a card (step 1 without a capable display, step 5's app icon).
    static let illustration: CGFloat = 96
    /// Step 4's menu bar strip.
    static let menuBarHeight: CGFloat = 24
    /// The highlight behind the status symbol, wider than it.
    static let menuBarHighlight = CGSize(width: 34, height: 20)
    /// The width of a key-cap column in step 4 (caps right-aligned in it).
    static let keyCapColumn: CGFloat = 92
    /// Step 3's login option cards.
    static let optionCardHeight: CGFloat = 44
    /// The glyph column of step 5's summary lines.
    static let summaryGlyphColumn: CGFloat = 20
    /// Step 2's fade at the bottom edge of its rows while they scroll.
    static let scrollFade = Space.xxxl
}
