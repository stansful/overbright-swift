// OverbrightDesign/Components/StatusChip.swift — a per-display limit or phase chip. DESIGN.md §5.7, §12.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 builds the button, its popover and the
// measured width. The WP0a body is a plain capsule label.
import SwiftUI

/// A chip on its own line under a card's readout; a button that opens a popover with one sentence and its actions.
public struct StatusChip: View {
    private let model: ChipModel
    private let actions: [ChipAction]

    /// A chip for `model` whose popover offers `actions`.
    public init(_ model: ChipModel, actions: [ChipAction]) {
        self.model = model; self.actions = actions
    }

    /// WP0a placeholder: glyph and text on the tint.
    public var body: some View {
        Label { Text(verbatim: model.text) } icon: { Image(symbol: model.symbol).foregroundStyle(model.color.color) }
            .font(.caption.weight(.medium))
            .padding(.horizontal, Space.m)
            .background(model.color.tint, in: Capsule(style: .continuous))
            .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
    }
}
