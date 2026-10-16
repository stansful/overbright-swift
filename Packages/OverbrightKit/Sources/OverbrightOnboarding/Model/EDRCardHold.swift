// OverbrightOnboarding/Model/EDRCardHold.swift — the Welcome card's registration with `OwnEDRSurfaces`
// (ARCHITECTURE.md §2.1 rule 6, §9.2 rule 5: every EDR surface registers; D6: the engine treats a display that shows
// our own EDR content as pre-held, never as idle headroom). One registration at a time, on the display the card is
// on; it moves with the window, ends while the window is hidden and when step 1 goes away.
import OverbrightCore

/// Holds `OwnEDRSurfaces` for the display the Welcome card shows EDR content on.
final class EDRCardHold {
    private let surfaces: OwnEDRSurfaces
    private var token: ObservationToken?
    /// The display held now, nil when none.
    private(set) var display: DisplayKey?

    /// A hold on `surfaces` that holds nothing yet.
    init(surfaces: OwnEDRSurfaces) {
        self.surfaces = surfaces
    }

    /// Holds `display`, releasing the previous one; nil releases.
    func hold(_ display: DisplayKey?) {
        guard display != self.display else { return }
        token?.cancel()
        token = nil
        self.display = display
        if let display { token = surfaces.hold(display) }
    }

    /// Releases the display held, if any.
    func release() { hold(nil) }
}
