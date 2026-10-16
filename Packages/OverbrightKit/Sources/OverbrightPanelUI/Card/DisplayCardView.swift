// OverbrightPanelUI/Card/DisplayCardView.swift — one display's card in the panel (and in Welcome). DESIGN.md §5.4.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed (Welcome uses it); WP10 builds the card
// (title, slider with the allowed-now marker, readout, chip line, context menu, VoiceOver actions).
// The WP0a body shows the display name and the readout only.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI

/// The card of one display that can boost or dim.
public struct DisplayCardView: View {
    private let status: DisplayStatus
    private let isMasterOn: Bool
    private let services: OverbrightServices

    /// A card for `status`; `services` gives the engine, settings and app control behind its actions.
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices) {
        self.status = status; self.isMasterOn = isMasterOn; self.services = services
    }

    /// WP0a placeholder: the name and the readout.
    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(verbatim: status.name)
                .font(.headline)
                .lineLimit(2)
            ReadoutText(Readout.values(for: status, isMasterOn: isMasterOn))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .background(Color(nsColor: .quaternarySystemFill),
                    in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

#Preview("Display card · idle") {
    let services = OverbrightServices.preview()
    let status = services.boost.status.displays.first
        ?? DisplayStatus(key: DisplayFixture.Keys.builtIn, name: "Built-in Display", phase: .idle, decision: nil,
                         appliedGain: 1, appliedFactor: 1, mechanism: .table, strategy: nil, lastReading: nil,
                         sdrWhite: nil)
    DisplayCardView(status: status, isMasterOn: false, services: services)
        .frame(width: 304)
        .padding()
        .overbrightThemeRoot()
}
