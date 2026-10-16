// OverbrightDesign/Components/ReadoutText.swift — a card's readout line. DESIGN.md §5.6, §2.2, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. Rounded with monospaced digits, the estimate
// prefix while uncalibrated, "Off" in `tertiaryLabelColor`. Never a numeric content transition (it grows CoreGraphics'
// glyph cache; Cranny gotcha): digits change in place.
import OverbrightCore
import OverbrightPolicy
import SwiftUI

/// "Bright room · ≈ ×1.29": rounded, monospaced digits, the estimate prefix while uncalibrated.
public struct ReadoutText: View {
    private let values: ReadoutValues

    /// The readout of `values` (`Readout.values(for:isMasterOn:)`).
    public init(_ values: ReadoutValues) { self.values = values }

    /// The text of `ValueText.make(_:)`, with the readout's help tag.
    public var body: some View {
        let text = ValueText.make(values)
        Text(verbatim: text.text)
            .font(OverbrightFont.readout.font)
            .foregroundStyle(values.state == .off ? .tertiary : .primary)
            .lineLimit(1)
            .contentTransition(.identity)
            .help(values.state == .boost ? ValueText.readoutHelp(isEstimate: values.isEstimate) : "")
            .accessibilityLabel(Text(verbatim: text.accessibilityText))
    }
}

#Preview("Readouts") {
    VStack(alignment: .leading, spacing: Space.s) {
        ReadoutText(ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil, isEstimate: true,
                                  dimPercent: nil))
        ReadoutText(ReadoutValues(state: .boost, appliedGain: 1.29, requestedGain: nil, nits: 775, preset: .brightRoom,
                                  isEstimate: false, dimPercent: nil))
        ReadoutText(ReadoutValues(state: .boost, appliedGain: 1.21, requestedGain: 1.47, nits: nil, preset: nil,
                                  isEstimate: true, dimPercent: nil))
        ReadoutText(ReadoutValues(state: .dim, appliedGain: 0.25, requestedGain: nil, nits: nil, preset: nil,
                                  isEstimate: false, dimPercent: 25))
    }
    .padding()
    .overbrightThemeRoot()
}
