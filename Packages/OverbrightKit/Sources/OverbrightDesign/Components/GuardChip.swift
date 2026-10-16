// OverbrightDesign/Components/GuardChip.swift — a footer chip with its menu. DESIGN.md §5.9, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. A menu button 24 pt high showing its setting
// (glyph + text on a neutral tint). The three chips fit 292 pt together in every language; when they would not, the
// footer sets `\.overbrightCompactGuardChips` and each drops to glyph + `compactText` (`GuardChip.rowWidth` measures).
import OverbrightCore
import SwiftUI

/// A footer chip showing a guard's setting; it opens a short menu.
public struct GuardChip: View {
    /// The chip's height.
    public static let height: CGFloat = 24

    /// The footer row's width.
    public static let rowWidth: CGFloat = 292
    /// The gap between footer chips.
    public static let spacing: CGFloat = Space.s

    private let model: GuardChipModel
    private let menu: [GuardChipMenuItem]
    @Environment(\.overbright) private var theme
    @Environment(\.overbrightCompactGuardChips) private var compact

    /// A chip for `model` with the rows `menu`.
    public init(_ model: GuardChipModel, menu: [GuardChipMenuItem]) {
        self.model = model; self.menu = menu
    }

    /// The width a row of `models` takes, full or compact (measured with the chip font).
    public static func rowWidth(of models: [GuardChipModel], compact: Bool) -> CGFloat {
        let chips = models.map { model -> CGFloat in
            let text = compact ? model.compactText : model.text
            let label = 12 + (text.map { Space.xs + OverbrightFont.chip.width(of: $0) } ?? 0)
            return max(label + 2 * Space.m, HitTarget.footerChipWidth)
        }
        return chips.reduce(0, +) + CGFloat(max(models.count - 1, 0)) * spacing
    }

    /// Whether a row of `models` needs the compact chips to fit `rowWidth`.
    public static func needsCompactRow(_ models: [GuardChipModel]) -> Bool {
        rowWidth(of: models, compact: false) > rowWidth
    }

    /// The chip: its full label, or glyph + value in a compact row.
    public var body: some View {
        chip(text: compact ? model.compactText : model.text)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
            .accessibilityValue(Text(verbatim: model.accessibilityValue ?? model.text))
    }

    private func chip(text: String?) -> some View {
        Menu {
            ForEach(Array(menu.enumerated()), id: \.offset) { _, item in GuardChipMenuRow(item: item) }
        } label: {
            HStack(spacing: Space.xs) {
                Image(symbol: model.symbol).font(.system(size: 12)).foregroundStyle(.secondary)
                if let text { Text(verbatim: text).font(OverbrightFont.chip.font).lineLimit(1) }
            }
            .padding(.horizontal, Space.m)
            .frame(minWidth: HitTarget.footerChipWidth, minHeight: Self.height)
            .background(SemanticColor.neutral.tint, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .overbrightFocusRing(cornerRadius: Self.height / 2)
    }
}

public extension EnvironmentValues {
    /// The footer's chips show glyph + value (the full row would not fit 292 pt in this language).
    @Entry var overbrightCompactGuardChips: Bool = false
}

/// One row of a guard chip's menu.
private struct GuardChipMenuRow: View {
    let item: GuardChipMenuItem

    var body: some View {
        switch item {
        case let .item(title, isChecked, perform):
            Toggle(isOn: Binding(get: { isChecked }, set: { _ in perform() })) { Text(verbatim: title) }
        case let .submenu(title, items):
            Menu {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in GuardChipMenuRow(item: item) }
            } label: { Text(verbatim: title) }
        case .separator:
            Divider()
        }
    }
}

#Preview("Footer chips") {
    HStack(spacing: GuardChip.spacing) {
        GuardChip(.battery(.belowThreshold, threshold: 20),
                  menu: GuardChipMenus.battery(current: .belowThreshold, threshold: 20, setGuard: { _ in }, setThreshold: { _ in }))
        GuardChip(.autoPause(anyRuleOn: true), menu: [])
        GuardChip(.timer(minutes: 30, remaining: .seconds(23 * 60)), menu: GuardChipMenus.timer(minutes: 30, set: { _ in }))
    }
    .padding()
    .frame(width: 320)
    .overbrightThemeRoot()
}
