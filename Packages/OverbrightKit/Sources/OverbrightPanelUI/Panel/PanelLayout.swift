// OverbrightPanelUI/Panel/PanelLayout.swift — the panel's fixed sizes and width budgets. DESIGN.md §5.1, §5.2, §5.4,
// §5.7, §5.9, §16 ("Length"); ARCHITECTURE.md §8.8 (width rules, measured by the fit tests, never by counting).
import CoreGraphics

/// Sizes of the panel and the width budgets its fit tests measure against.
public nonisolated enum PanelLayout {
    /// The panel's width.
    public static let width: CGFloat = 320
    /// The panel's padding around the cards (320 − 2 × 8 = 304).
    public static let outerPadding: CGFloat = 8
    /// A display card's width.
    public static let cardWidth: CGFloat = width - 2 * outerPadding
    /// A card's inner padding.
    public static let cardPadding: CGFloat = 12
    /// The width inside a card: the chip line's budget (DESIGN.md §5.7: 280 pt).
    public static let cardInnerWidth: CGFloat = cardWidth - 2 * cardPadding
    /// The readout's budget (one line, DESIGN.md §5.6).
    public static let readoutWidth: CGFloat = 200
    /// The slider's track, whose boost half is half of it; also the value tag's budget.
    public static let trackWidth: CGFloat = 240
    /// The footer's three guard chips together (DESIGN.md §5.9): the cards' width, so the row starts and ends with
    /// their edges (the footer is inset like the cards).
    public static let footerWidth: CGFloat = cardWidth
    /// The gap between footer chips.
    public static let footerChipGap: CGFloat = 6
    /// The header and the footer.
    public static let barHeight: CGFloat = 44
    /// The gap between cards.
    public static let cardGap: CGFloat = 8
    /// The panel grows to this fraction of the screen's visible height; beyond it the card list scrolls while the
    /// header, banner and footer stay put (DESIGN.md §5.1).
    public static let maximumHeightFraction: CGFloat = 0.7
    /// Cards visible before the list scrolls when there are four or more (DESIGN.md §5.11).
    public static let visibleCardsBeforeScrolling = 3
    /// A display card's usual height (title, slider, readout and a chip line), until the cards are measured.
    public static let cardHeight: CGFloat = 112
    /// How much of the next card a scrolling list shows below its last whole card, faded out: the scroll cue.
    public static let scrollPeek: CGFloat = 24
    /// The scrolling list of four or more cards: the first three cards (their measured heights, else `cardHeight`
    /// each), their gaps, and the gap and `scrollPeek` of the next one, so the view ends on a card boundary plus the
    /// peek, never through a card's slider.
    public static func scrollingListHeight(cardHeights: [CGFloat]) -> CGFloat {
        let count = visibleCardsBeforeScrolling
        let heights = cardHeights.count >= count ? Array(cardHeights.prefix(count))
            : Array(repeating: cardHeight, count: count)
        return heights.reduce(0, +) + CGFloat(count) * cardGap + scrollPeek
    }
    /// The frame of the glyphs at the slider's ends (they draw 16 and 17 pt wide at 14 pt; the row is 280 pt).
    public static let sliderGlyph: CGFloat = 14
    /// The header's status symbol.
    public static let headerSymbol: CGFloat = 16
}
