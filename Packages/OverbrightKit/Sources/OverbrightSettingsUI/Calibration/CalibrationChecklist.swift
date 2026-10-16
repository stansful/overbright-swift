// OverbrightSettingsUI/Calibration/CalibrationChecklist.swift — "Before starting" (DESIGN.md §9): a checklist with live
// state where Overbright can read it: the power source, other color or brightness apps (the conflict catalogue's
// S1–S3 matches) and the thermal state; the display brightness and Automatically adjust brightness, True Tone and Night
// Shift are asked, because no public API reads them. Start is enabled when the live items pass. Pure (tested).
import OverbrightCore

/// The calibration checklist.
nonisolated enum CalibrationChecklist {
    /// One item.
    enum Item: CaseIterable, Hashable, Sendable {
        /// "Plug in your Mac" (live: the power source).
        case pluggedIn
        /// "Set brightness to maximum" (asked).
        case maximumBrightness
        /// Turn off Automatically adjust brightness, True Tone and Night Shift (asked).
        case displayAdjustmentsOff
        /// "No other color or brightness app is running" (live).
        case noOtherApps
        /// "Your Mac is cool" (live: the thermal state).
        case cool

        /// Overbright can read the item's state.
        var isLive: Bool {
            switch self {
            case .pluggedIn, .noOtherApps, .cool: true
            case .maximumBrightness, .displayAdjustmentsOff: false
            }
        }
    }

    /// Whether a live item passes now; nil for an asked item. A power source macOS does not report passes (a Mac
    /// without a battery).
    static func passes(_ item: Item, _ snapshot: SystemSnapshot) -> Bool? {
        switch item {
        case .pluggedIn: snapshot.power.source != .battery
        case .noOtherApps: !snapshot.conflicts.contains { $0.severity != .benign }
        case .cool: snapshot.thermal <= .fair
        case .maximumBrightness, .displayAdjustmentsOff: nil
        }
    }

    /// Start is enabled: every live item passes.
    static func canStart(_ snapshot: SystemSnapshot) -> Bool {
        Item.allCases.allSatisfy { passes($0, snapshot) ?? true }
    }
}
