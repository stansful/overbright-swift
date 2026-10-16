// OverbrightPanelUI/QA/ScriptedStatuses.swift — named engine statuses for snapshots and `--qa-state`.
// DESIGN.md §5.13; ARCHITECTURE.md §8.5, §10.0 (PanelUI seam). The shell reads `names` and `status(named:)`;
// WP10 adds every state of the gallery (chips, banners, phases, HUDs). The WP0a body has the two neutral states.
import OverbrightCore

/// The named statuses of DESIGN.md §5.13, each a `BoostStatus` that drives `PreviewBoostControl`.
public enum ScriptedStatuses {
    /// Every name, in gallery order.
    public static var names: [String] { ["off", "standard"] }

    /// The status called `name`, or nil for an unknown name.
    public static func status(named name: String) -> BoostStatus? {
        switch name {
        case "off": status(isOn: false)
        case "standard": status(isOn: true)
        default: nil
        }
    }

    /// The built-in display and the MSI (HDR on), both idle at Standard.
    private static func status(isOn: Bool) -> BoostStatus {
        let fixtures = DisplayFixture.builtinXDRLidOpen.displays + DisplayFixture.mpg322uxHDROn.displays
        let displays = fixtures.map { display in
            DisplayStatus(key: display.key, name: display.facts.name, phase: .idle, decision: nil, appliedGain: 1,
                          appliedFactor: 1, mechanism: .table, strategy: nil, lastReading: nil, sdrWhite: nil)
        }
        return BoostStatus(isOn: isOn, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: displays,
                           banner: nil, symbol: isOn ? .on : .off)
    }
}
