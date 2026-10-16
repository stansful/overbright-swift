// OverbrightCore/Model/Policy/Banner.swift — the one "Paused because…" banner. ARCHITECTURE.md §3.4, §6.3; DESIGN.md §5.8.
import Foundation

/// The one "Paused because…" banner the panel shows (DESIGN.md §5.8), highest precedence wins.
public nonisolated enum Banner: Hashable, Sendable {
    /// "Pause for…" until the date.
    case userPaused(until: Date)
    /// A conflicting app (S1/S2).
    case conflict(ConflictingApp)
    /// A scaled table at launch that rescue could not clear.
    case foreignTableAtLaunch
    /// The flicker guard stopped a display.
    case flickerStop(display: DisplayKey)
    /// An unidentified writer keeps changing a display's table.
    case unattributedDrift(display: DisplayKey)
    /// An identified app changed a display's table.
    case attributedDrift(ConflictingApp, display: DisplayKey)
    /// The Focus filter turned extra brightness off.
    case focusOff
    /// Thermal state critical.
    case thermalCritical
    /// Low Power Mode.
    case lowPowerMode
    /// On battery below the threshold.
    case battery(percent: Int, threshold: Int)
    /// On battery with "only on the adapter".
    case onBattery
    /// Outside the schedule window.
    case outsideSchedule(ScheduleWindow)
}
