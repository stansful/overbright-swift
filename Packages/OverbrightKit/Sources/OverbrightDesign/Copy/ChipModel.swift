// OverbrightDesign/Copy/ChipModel.swift — what one status chip shows. DESIGN.md §5.7, §12.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(reason:phase:failedTries:)` are fixed; WP9 writes
// the copy (keys in Design's catalog) and the mapping of every `LimitReason` and engine phase.
import OverbrightCore

/// A per-display status chip: glyph, short text and the one-sentence explanation of its popover.
public struct ChipModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The glyph colour and the tint behind the text.
    public var color: SemanticColor
    /// The chip text ("Limited by macOS"), already localized.
    public var text: String
    /// The popover sentence, already localized.
    public var explanation: String
    /// The VoiceOver label (the full text when `text` is truncated, e.g. a long app name).
    public var accessibilityLabel: String

    /// A chip.
    public init(symbol: OverbrightSymbol, color: SemanticColor, text: String, explanation: String,
                accessibilityLabel: String) {
        self.symbol = symbol; self.color = color; self.text = text; self.explanation = explanation
        self.accessibilityLabel = accessibilityLabel
    }

    /// The chip of a display: "Preparing…" and "No extra range" come from the engine phase and win while they apply,
    /// else the first per-display reason in policy order; nil when nothing per-display applies (global reasons are the
    /// banner's). `failedTries` changes the "No extra range" chip after two tries (DESIGN.md §12.2).
    /// WP0a stub: no chip.
    public static func make(reason: LimitReason?, phase: EnginePhase, failedTries: Int) -> ChipModel? {
        _ = (reason, phase, failedTries)
        return nil
    }
}
