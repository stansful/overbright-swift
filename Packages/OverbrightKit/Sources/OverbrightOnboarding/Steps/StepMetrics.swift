// OverbrightOnboarding/Steps/StepMetrics.swift — the steps' own measurements (DESIGN.md §8), so no step writes a
// literal size or opacity (ARCHITECTURE.md §9.2 rule 3). The window's are the chrome's `WelcomeMetrics`.
import CoreGraphics
import OverbrightDesign

/// Sizes inside the Welcome steps.
nonisolated enum StepMetrics {
    /// The stage keeps its content below the hidden title bar and its close button (32 pt on macOS 27).
    static let titleBarInset = Space.huge
    /// The stage's bottom inset.
    static let stageBottomInset = Space.xl
    /// The height the stage's content gets.
    static let stageContentHeight = WelcomeMetrics.stageHeight - titleBarInset - stageBottomInset
    /// Step 1's before/after card: the stage's content height, at most this wide.
    static let cardWidth: CGFloat = 448
    /// The glyph of a display row and of step 4's rows.
    static let rowGlyph: CGFloat = 20
    /// The width of a display row's glyph column.
    static let rowGlyphColumn: CGFloat = 28
    /// The illustration of a step without a card (step 1 without a capable display, step 5's app icon).
    static let illustration: CGFloat = 96
    /// Step 4's menu bar strip.
    static let menuBarHeight: CGFloat = 24
    /// The status symbol inside the menu bar strip.
    static let menuBarSymbol: CGFloat = 14
    /// The highlight behind the status symbol, wider than it.
    static let menuBarHighlight = CGSize(width: 34, height: 20)
    /// The strength of a step card's separator hairline (DESIGN.md §2.1 `cardStroke`: 50 %, 100 % with Increase
    /// Contrast).
    static let hairline: Double = 0.5
    /// The opacity of the menu bar strip's material stand-in.
    static let menuBarFill: Double = 0.6
    /// The width of a key-cap column in step 4 (caps right-aligned in it).
    static let keyCapColumn: CGFloat = 92
    /// Step 3's login option cards.
    static let optionCardHeight: CGFloat = 44
    /// Step 2's fade at the bottom edge of its rows while they scroll.
    static let scrollFade = Space.xxxl
}
