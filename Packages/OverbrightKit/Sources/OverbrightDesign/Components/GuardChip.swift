// OverbrightDesign/Components/GuardChip.swift — a footer chip with its menu. DESIGN.md §5.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 builds the real chip (glyph + value
// fallback when the row does not fit). The WP0a body is a plain menu button.
import SwiftUI

/// A footer chip showing a guard's setting; it opens a short menu.
public struct GuardChip: View {
    private let model: GuardChipModel
    private let menu: [GuardChipMenuItem]

    /// A chip for `model` with the rows `menu`.
    public init(_ model: GuardChipModel, menu: [GuardChipMenuItem]) {
        self.model = model; self.menu = menu
    }

    /// WP0a placeholder: a borderless menu button.
    public var body: some View {
        Menu {
            ForEach(Array(menu.enumerated()), id: \.offset) { _, item in GuardChipMenuRow(item: item) }
        } label: {
            Label { Text(verbatim: model.text) } icon: { Image(symbol: model.symbol) }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
    }
}

/// One row of a guard chip's menu.
private struct GuardChipMenuRow: View {
    let item: GuardChipMenuItem

    var body: some View {
        switch item {
        case let .item(title, isChecked, perform):
            Button(action: perform) {
                if isChecked { Label { Text(verbatim: title) } icon: { Image(symbol: .checkmark) } } else { Text(verbatim: title) }
            }
        case let .submenu(title, items):
            Menu {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in GuardChipMenuRow(item: item) }
            } label: { Text(verbatim: title) }
        case .separator:
            Divider()
        }
    }
}
