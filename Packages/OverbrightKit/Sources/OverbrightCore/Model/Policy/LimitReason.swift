// OverbrightCore/Model/Policy/LimitReason.swift — why a display is not at the user's level. ARCHITECTURE.md §3.4, §6.1–§6.3.
import Foundation

/// Why a display is not at the level the user picked. Ordered by precedence; the first one is the chip.
public nonisolated enum LimitReason: Hashable, Sendable {
    /// The master switch is off.
    case masterOff
    /// The display cannot boost (or dim) at all.
    case notSupported(DisplayVerdict)
    /// Locked, screensaver, asleep, other session.
    case shielded
    /// A conflicting app runs.
    case conflict(ConflictingApp)
    /// The engine stopped the display on its own.
    case tripped(TripCause)
    /// "Pause for…" until the date.
    case userPaused(until: Date)
    /// The Focus filter turned extra brightness off.
    case focusOff
    /// The per-display "Use extra brightness" switch is off (boost half only).
    case boostNotEnabled
    /// Thermal state critical.
    case thermalCritical
    /// Low Power Mode.
    case lowPowerMode
    /// On battery below the threshold.
    case battery(percent: Int, threshold: Int)
    /// `BatteryGuard.onlyOnAdapter`.
    case onBattery
    /// Outside the schedule window.
    case outsideSchedule
    /// A full-screen video plays on the display.
    case fullScreenVideo
    /// A full-screen app is on the display.
    case fullScreenApp
    /// A listed app pauses the display.
    case pausedApp(bundleID: String)
    /// A game is frontmost on the display.
    case game
    /// An OLED display idles past the threshold.
    case oledIdle
    /// A reason only: never a stop, never a cue to escalate.
    case hdrSuppressedByMacOS
    /// A cap, not a stop.
    case thermalSerious
    /// `CapMode.safe` binds (static top or live bound).
    case safeLimit
    /// OLED Safe cap binds.
    case oledLimit
    /// The taper binds: system brightness is below full (§5.4).
    case nearFullBrightnessOnly
    /// 0.97 × H_live binds ("Limited by macOS").
    case headroom
    /// Gating (D6).
    case waitingForHeadroom
    /// True for reasons that stop the boost half only; dimming still applies (ARCHITECTURE.md §6.1).
    public var blocksBoostOnly: Bool {
        switch self {
        case .boostNotEnabled, .thermalCritical, .lowPowerMode, .battery, .onBattery, .outsideSchedule,
             .fullScreenVideo, .fullScreenApp, .pausedApp, .game, .oledIdle: true
        default: false
        }
    }
    /// Reasons that apply to every display at once: shown once as the banner, never as per-card chips (§6.3).
    public var isGlobal: Bool {
        switch self {
        case .userPaused, .focusOff, .thermalCritical, .lowPowerMode, .battery, .onBattery, .outsideSchedule: true
        case .conflict(let app): app.severity == .booster || app.severity == .gammaWriter
        default: false
        }
    }
    /// Reasons an automation stops or caps the boost on its own: battery, Low Power, heat and the schedule (DESIGN.md
    /// §6 (4)); never the full-screen, app, game or idle pauses the user caused. The timer has its own change.
    public var isAutomation: Bool {
        switch self {
        case .battery, .onBattery, .lowPowerMode, .thermalSerious, .thermalCritical, .outsideSchedule: true
        default: false
        }
    }
}
