// OverbrightDesign/Copy/ValueText.swift — a level in canonical units. DESIGN.md §5.5, §5.6, §12.5, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:)` are fixed; WP9 writes the formats.
import OverbrightPolicy

/// The readout, value-tag and VoiceOver text of a level ("Bright room · ≈ ×1.29" / "Bright room, about 1.29 times,
/// not calibrated").
public struct ValueText: Hashable, Sendable {
    /// The visible text.
    public var text: String
    /// The VoiceOver value.
    public var accessibilityText: String

    /// A value text.
    public init(text: String, accessibilityText: String) { self.text = text; self.accessibilityText = accessibilityText }

    /// The canonical text of `values` (multipliers through `FormatStyle`, nits rounded to 5 and prefixed "≈").
    /// WP0a stub: empty text.
    public static func make(_ values: ReadoutValues) -> ValueText {
        _ = values
        return ValueText(text: "", accessibilityText: "")
    }
}
