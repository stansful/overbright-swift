// OverbrightPanelUI/Panel/DimState.swift — whether "Dim All Displays" reads "Stop Dimming". ARCHITECTURE.md §4.9
// (`toggleDim`: if any display that can dim is above Standard light, every one dims; otherwise they return), DESIGN.md
// §4.3, §4.4 (Dock menu), §5.3 ("⋯" menu). One rule for the panel, the status menu and the Dock menu.
import OverbrightCore

/// The Dim All toggle's state.
public enum DimState {
    /// Every display that can dim is dimmed (so the toggle undoes the dimming); false when none can dim or the master
    /// is off.
    public static func isEveryDisplayDimmed(_ status: BoostStatus) -> Bool {
        guard status.isOn else { return false }
        let dimmable = status.displays.filter { $0.decision?.eligibility.verdict.allowsDim ?? true }
        guard !dimmable.isEmpty else { return false }
        return dimmable.allSatisfy(isDimmed)
    }

    /// The display shows less than Standard light (or is about to: its decision is a dim target).
    public static func isDimmed(_ display: DisplayStatus) -> Bool {
        if display.phase == .dimmed { return true }
        if case .dim? = display.decision?.target { return true }
        return false
    }
}
