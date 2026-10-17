// OverbrightPanelUI/Panel/PanelCard.swift — the one card style of the panel: the display cards, the calibration tip,
// the Fill Light card and the expanded "Why?" rows. DESIGN.md §2.1 (`card` fill and `cardStroke` hairline, opaque with a
// full-strength hairline under Increase Contrast), §2.3 (`Radius.card`), §5.2 and §5.4 (304 pt wide, padding 12), §2.4
// (cards are content: no glass). Every card is exactly `PanelLayout.cardWidth` wide, so their edges line up with each
// other and with the banner; its content is offered the 280-pt inner width.
import OverbrightDesign
import SwiftUI

/// The panel's card background, edge and size.
struct PanelCard: ViewModifier {
    @Environment(\.overbright) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        content
            .padding(PanelLayout.cardPadding)
            .frame(width: PanelLayout.cardWidth, alignment: .leading)
            .background(theme.color(.card), in: shape)
            .overlay(shape.strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
    }
}

extension View {
    /// The view as one of the panel's cards (304 pt wide, padding 12, the `card` fill and `cardStroke` edge).
    func panelCard() -> some View { modifier(PanelCard()) }
}
