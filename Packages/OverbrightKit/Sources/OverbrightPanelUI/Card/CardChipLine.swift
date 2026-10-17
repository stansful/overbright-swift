// OverbrightPanelUI/Card/CardChipLine.swift — a card's chip line: the status chip and, for a display whose extra
// brightness is off, its inline "Turn on". DESIGN.md §5.4, §5.7 (the chip on its own line, at most the card's 280-pt
// inner width), §16 ("Length"). The two share one line when they fit it together; otherwise "Turn on" drops under the
// chip, so a long translation never pushes the chip past the card's edge or against the button.
import OverbrightDesign
import SwiftUI

/// The chip and the "Turn on" button of one card, inside the card's inner width.
struct CardChipLine<Chip: View, TurnOn: View>: View {
    @ViewBuilder let chip: () -> Chip
    @ViewBuilder let turnOn: () -> TurnOn

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) {
                chip()
                turnOn()
            }
            VStack(alignment: .leading, spacing: Space.xs) {
                chip()
                turnOn()
            }
        }
        .frame(width: PanelLayout.cardInnerWidth, alignment: .leading)
    }
}
