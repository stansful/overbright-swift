// OverbrightDesign/Copy/GuardChipModel.swift — what one footer guard chip shows. DESIGN.md §5.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.

/// A footer chip (Battery, Auto-pause, Timer): its setting, never a live value.
public struct GuardChipModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The setting ("Below 20 %"), already localized.
    public var text: String
    /// The VoiceOver label ("Battery: below 20 %").
    public var accessibilityLabel: String

    /// A footer chip.
    public init(symbol: OverbrightSymbol, text: String, accessibilityLabel: String) {
        self.symbol = symbol; self.text = text; self.accessibilityLabel = accessibilityLabel
    }
}
