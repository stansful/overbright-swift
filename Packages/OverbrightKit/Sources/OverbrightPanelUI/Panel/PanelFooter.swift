// OverbrightPanelUI/Panel/PanelFooter.swift — the footer's guard chips in one 292-pt row; when the row would not fit
// (a long translation, or the widest settings), every chip drops to glyph + value, and as a last resort to its glyph
// (the setting stays in its menu and VoiceOver label). DESIGN.md §5.9, §16 ("Length").
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The footer row.
struct PanelFooter: View {
    /// How much of each chip shows.
    enum Style: CaseIterable { case full, compact, glyphs }

    let chips: [FooterChip]
    /// The panel's focus (nil outside the panel: tests measure the row alone).
    let focus: FocusState<PanelFocus?>.Binding?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(.full)
            row(.compact)
            row(.glyphs)
        }
        .frame(maxWidth: PanelLayout.footerWidth, alignment: .leading)
        .frame(height: PanelLayout.barHeight)
    }

    /// The row in `style`.
    func row(_ style: Style) -> some View {
        HStack(spacing: PanelLayout.footerChipGap) {
            ForEach(chips, id: \.kind) { chip in
                GuardChip(Self.model(of: chip, style), menu: chip.menu)
                    .frame(minWidth: HitTarget.footerChipWidth)
                    .panelFocus(focus, Self.focus(for: chip.kind), cornerRadius: HitTarget.minimum.height / 2)
            }
        }
        .fixedSize()
    }

    /// The chip's model in `style`.
    static func model(of chip: FooterChip, _ style: Style) -> GuardChipModel {
        switch style {
        case .full: chip.model
        case .compact: chip.compact
        case .glyphs: GuardChipModel(symbol: chip.compact.symbol, text: "", accessibilityLabel: chip.model.accessibilityLabel)
        }
    }

    /// The focus value of a chip.
    static func focus(for kind: FooterChip.Kind) -> PanelFocus {
        switch kind {
        case .battery: .footerBattery
        case .autoPause: .footerAutoPause
        case .timer: .footerTimer
        }
    }
}
