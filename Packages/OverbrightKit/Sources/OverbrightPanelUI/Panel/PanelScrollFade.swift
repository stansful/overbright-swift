// OverbrightPanelUI/Panel/PanelScrollFade.swift — the mask of the scrolling card list (four or more displays): opaque,
// then the last `PanelLayout.scrollPeek` points fade out, so the next card's top reads as "more below" (DESIGN.md
// §5.11). The list adds the same height of padding at its end, so the last card scrolls clear of the fade. A mask uses
// only opacity: black and clear here are not colours anybody sees.
import SwiftUI

/// The fade at the bottom of the scrolling card list.
struct PanelScrollFade: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: PanelLayout.scrollPeek)
        }
    }
}
