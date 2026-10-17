// OverbrightPanelUI/Panel/PanelFooter.swift — the footer's guard chips in one 304-pt row, inset like the cards so it
// lines up with their edges; when the row would not fit
// (a long translation, or the widest settings), every chip drops to glyph + value, and as a last resort to its glyph
// (the setting stays in its menu and VoiceOver value). Space or Return on a focused chip opens its menu (DESIGN.md
// §5.12): the same rows as an AppKit menu at the chip, since a SwiftUI menu cannot be opened from code. DESIGN.md §5.9,
// §16 ("Length").
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
    @Environment(\.panelMenuPresenter) private var menus
    @State private var anchors = FooterAnchors()

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
                let anchor = anchors.reference(for: chip.kind)
                GuardChip(Self.model(of: chip, style), menu: chip.menu)
                    .frame(minWidth: HitTarget.footerChipWidth)
                    .background { MenuAnchor(reference: anchor) }
                    .panelFocus(focus, Self.focus(for: chip.kind), cornerRadius: HitTarget.minimum.height / 2) {
                        menus.present(anchor, KeyboardMenu.items(chip.menu))
                    }
            }
        }
        .fixedSize()
    }

    /// The chip's model in `style` (VoiceOver's label and value are the same in every style).
    static func model(of chip: FooterChip, _ style: Style) -> GuardChipModel {
        switch style {
        case .full: chip.model
        case .compact: chip.compact
        case .glyphs:
            GuardChipModel(symbol: chip.compact.symbol, text: "", accessibilityLabel: chip.model.accessibilityLabel,
                           compactText: nil, accessibilityValue: chip.model.accessibilityValue)
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

/// The AppKit anchors the footer chips' keyboard menus open at, one per chip.
@MainActor final class FooterAnchors {
    private var references: [FooterChip.Kind: MenuAnchorReference] = [:]

    /// The anchor of `kind`'s chip.
    func reference(for kind: FooterChip.Kind) -> MenuAnchorReference {
        if let reference = references[kind] { return reference }
        let reference = MenuAnchorReference()
        references[kind] = reference
        return reference
    }
}

#Preview("Footer · default, widest") {
    let settings = SettingsStore(defaults: InMemoryDefaults())
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    VStack(alignment: .leading) {
        PanelFooter(chips: FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil, now: now,
                                             editApps: {}), focus: nil)
        PanelFooter(chips: FooterChips.chips(settings: settings, hasBattery: true,
                                             autoOffAt: now.addingTimeInterval(90 * 60), now: now, editApps: {}),
                    focus: nil)
    }
    .padding(.horizontal, Space.l)
    .frame(width: PanelLayout.width)
    .overbrightThemeRoot()
}
