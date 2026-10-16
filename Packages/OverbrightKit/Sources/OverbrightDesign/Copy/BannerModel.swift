// OverbrightDesign/Copy/BannerModel.swift — what the panel's one banner shows. DESIGN.md §5.8, §12.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:)` are fixed; WP9 writes the copy and the
// precedence-specific actions.
import OverbrightCore

/// The panel's banner for a reason that applies to every display (also the first line of the status menu).
public struct BannerModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The glyph colour and the 10 % card tint.
    public var color: SemanticColor
    /// The sentence ("Paused because Low Power Mode is on."), already localized.
    public var sentence: String
    /// The primary action's title (sentence case), if any.
    public var primaryTitle: String?
    /// The secondary action's title, if any.
    public var secondaryTitle: String?

    /// A banner.
    public init(symbol: OverbrightSymbol, color: SemanticColor, sentence: String, primaryTitle: String?,
                secondaryTitle: String?) {
        self.symbol = symbol; self.color = color; self.sentence = sentence
        self.primaryTitle = primaryTitle; self.secondaryTitle = secondaryTitle
    }

    /// The banner of `banner` (DESIGN.md §12.3). WP0a stub: a neutral banner without text or actions.
    public static func make(_ banner: Banner) -> BannerModel {
        _ = banner
        return BannerModel(symbol: .infoCircleFill, color: .neutral, sentence: "", primaryTitle: nil, secondaryTitle: nil)
    }
}
