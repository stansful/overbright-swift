// OverbrightDesign/Components/ReadoutText.swift — a card's readout line. DESIGN.md §5.6, §2.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 owns the styling. Never a numeric
// content transition (it grows CoreGraphics' glyph cache; Cranny gotcha).
import OverbrightPolicy
import SwiftUI

/// "Bright room · ≈ ×1.29": rounded, monospaced digits, the estimate prefix while uncalibrated.
public struct ReadoutText: View {
    private let values: ReadoutValues

    /// The readout of `values` (`Readout.values(for:isMasterOn:)`).
    public init(_ values: ReadoutValues) { self.values = values }

    /// The text of `ValueText.make(_:)`.
    public var body: some View {
        let text = ValueText.make(values)
        Text(verbatim: text.text)
            .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
            .accessibilityLabel(Text(verbatim: text.accessibilityText))
    }
}
