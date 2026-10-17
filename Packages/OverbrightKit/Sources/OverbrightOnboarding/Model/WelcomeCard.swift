// OverbrightOnboarding/Model/WelcomeCard.swift — what step 1's stage shows (DESIGN.md §8, §0 #12; D16): the
// before/after card at Bright room on a display that can show extra brightness, else a static illustration. Only the
// card is brighter: its right part is our own EDR content (Design's `EDRPreviewSurface`), no table is written, and
// the card is registered with `OwnEDRSurfaces` on the display its window is on while it is visible (ARCHITECTURE.md
// D6: the engine counts it as range already held), never in a simulated run, where the card is an SDR stand-in. The
// card only ever shows the light of the display it is drawn on: when the window is on a display that cannot show extra
// brightness (Sidecar, an LCD, an XDR on Safe) while another can, the stage shows the illustration and asks to move
// the window, rather than another display's Bright room drawn where Overbright would add nothing (WP14 C-ONBOARD-4).
import OverbrightCore
import OverbrightPolicy

/// Step 1's stage.
enum WelcomeCard: Hashable {
    /// The before/after card: Standard on the left, `gain` (Bright room on `display`) on the right.
    case preview(display: DisplayKey, gain: Double)
    /// No display can boost yet, and some are still being read: the illustration, without a verdict.
    case checking
    /// None of the displays has extra range now: the illustration and "The next step shows why."
    case noneCapable
    /// The window is on a display without extra range while another display has it: the illustration and "Move this
    /// window to another display to compare."
    case otherDisplay

    /// The level the right part of the card shows.
    static let level = LevelPreset.brightRoom

    /// The card for `rows` in a window on `windowDisplay`: that display's Bright room when it can boost; the
    /// illustration with `otherDisplay` when it cannot but another display can, or `checking` while it is not read
    /// yet. Before the window's display is known (and in a simulated run, which never reads it) the first display that
    /// can boost (built-in first), drawn as the SDR stand-in because nothing is held (`drawsStandIn`).
    static func make(rows: [WelcomeDisplayRow], windowDisplay: DisplayKey?) -> WelcomeCard {
        let capable = rows.filter(\.canBoost)
        if let windowDisplay {
            if let row = capable.first(where: { $0.key == windowDisplay }) {
                return .preview(display: row.key, gain: gain(top: row.top))
            }
            guard let own = rows.first(where: { $0.key == windowDisplay }), own.verdict != .checking else {
                return .checking
            }
            if !capable.isEmpty { return .otherDisplay }
        } else if let row = capable.first {
            return .preview(display: row.key, gain: gain(top: row.top))
        }
        return rows.contains { $0.verdict == .checking } ? .checking : .noneCapable
    }

    /// The light gain of Bright room on a display whose boost half tops at `top` (×1.29 on the M4 Max built-in in
    /// Safe, ARCHITECTURE.md §5.3).
    static func gain(top: Double) -> Double {
        LevelMapping.requestedGain(for: level.position, top: top)
    }

    /// The display to register with `OwnEDRSurfaces`: the one the window is on, while the card shows real EDR content
    /// (not simulated) and the window can be seen; nil otherwise.
    func heldDisplay(windowDisplay: DisplayKey?, isWindowVisible: Bool, simulated: Bool) -> DisplayKey? {
        guard case .preview = self, !simulated, isWindowVisible else { return nil }
        return windowDisplay
    }

    /// The card draws its SDR stand-in unless a display is held for it (`heldDisplay`): EDR content is only ever on
    /// screen while it is registered, never in a simulated run, never while the window is hidden, and not before the
    /// window's display is known.
    static func drawsStandIn(held: DisplayKey?) -> Bool { held == nil }

    /// The card draws its SDR stand-in instead of EDR content: under `--qa-simulate`, and whenever the display ports
    /// are the Core fakes (previews, tests, scripted QA states), so nothing a developer runs raises real headroom (D24).
    static func simulates(_ services: OverbrightServices, arguments: LaunchArguments = .current) -> Bool {
        arguments.qaSimulates || services.displays is FakeDisplayDirectory
    }
}
