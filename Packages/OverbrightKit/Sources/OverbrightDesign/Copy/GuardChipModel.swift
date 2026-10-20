// OverbrightDesign/Copy/GuardChipModel.swift — what one footer guard chip shows. DESIGN.md §5.9, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. A footer chip shows its setting, never a live value
// (the timer's countdown excepted); when the three chips do not fit 304 pt, each drops to glyph + `compactText`.
import Foundation

/// A footer chip (Battery, Auto-pause, Timer): its setting, never a live value.
public nonisolated struct GuardChipModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The setting ("Below 20 %"), already localized.
    public var text: String
    /// The VoiceOver label ("Battery limit").
    public var accessibilityLabel: String
    /// The short value shown next to the glyph when the footer is too narrow ("20%"); nil shows the glyph alone.
    public var compactText: String?
    /// The VoiceOver value ("Below 20%").
    public var accessibilityValue: String?

    /// A footer chip.
    public init(symbol: OverbrightSymbol, text: String, accessibilityLabel: String) {
        self.symbol = symbol; self.text = text; self.accessibilityLabel = accessibilityLabel
    }

    /// A footer chip with its compact text and VoiceOver value.
    public init(symbol: OverbrightSymbol, text: String, accessibilityLabel: String, compactText: String?,
                accessibilityValue: String?) {
        self.init(symbol: symbol, text: text, accessibilityLabel: accessibilityLabel)
        self.compactText = compactText; self.accessibilityValue = accessibilityValue
    }
}
