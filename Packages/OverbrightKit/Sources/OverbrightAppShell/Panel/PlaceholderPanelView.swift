// OverbrightAppShell/Panel/PlaceholderPanelView.swift — the panel's content until WP10 builds it. DESIGN.md §5.
// Seeded by WP0a so that `make run` shows a panel under the status item: the header (symbol and name), one
// `DisplayCardView` per display the engine publishes, and Quit. WP10 replaces it with the real panel (master switch,
// overflow menu, banner, cards with sliders and chips, footer chips, keyboard map).
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI

/// The WP0a panel content.
struct PlaceholderPanelView: View {
    let services: OverbrightServices
    let onQuit: () -> Void

    var body: some View {
        let status = services.boost.status
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Image(nsImage: StatusSymbolImage.image(for: status.symbol))
                    .renderingMode(.template)
                    .accessibilityHidden(true)
                Text(verbatim: "Overbright")
                    .font(.headline)
                Spacer()
            }
            ForEach(status.displays, id: \.key) { display in
                DisplayCardView(status: display, isMasterOn: status.isOn, services: services)
            }
            Divider()
            HStack {
                Spacer()
                Button(action: onQuit) { Text(Self.quitTitle) }
                    .keyboardShortcut("q")
            }
        }
        .padding(Space.l)
        .frame(width: PanelController.width)
    }

    /// "Quit Overbright" (the panel's own table, StatusMenu, is WP10's).
    static var quitTitle: String {
        String(localized: "Quit Overbright", table: "StatusMenu", bundle: .module,
               comment: "Panel: the button that quits the app")
    }
}
