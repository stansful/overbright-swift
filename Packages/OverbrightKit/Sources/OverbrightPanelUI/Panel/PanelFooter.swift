// OverbrightPanelUI/Panel/PanelFooter.swift — the footer's guard chips in one 292-pt row; when the row would not fit
// (a long translation), every chip drops to glyph + value. DESIGN.md §5.9, §16 ("Length").
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The footer row.
struct PanelFooter: View {
    let chips: [FooterChip]
    let focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(compact: false)
            row(compact: true)
        }
        .frame(maxWidth: PanelLayout.footerWidth, alignment: .leading)
        .frame(height: PanelLayout.barHeight)
    }

    private func row(compact: Bool) -> some View {
        HStack(spacing: PanelLayout.footerChipGap) {
            ForEach(chips, id: \.kind) { chip in
                GuardChip(compact ? chip.compact : chip.model, menu: chip.menu)
                    .frame(minWidth: HitTarget.footerChipWidth)
                    .panelFocus(focus, Self.focus(for: chip.kind), cornerRadius: HitTarget.minimum.height / 2)
            }
        }
        .fixedSize()
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
