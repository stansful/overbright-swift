// OverbrightCore/Model/System/SystemEvent.swift — discrete system events. ARCHITECTURE.md §3.3, §4.1, §7.1, D9.
import CoreGraphics

/// Discrete events that make the engine re-present triggers, re-capture baselines or re-check headroom.
/// Shield events (`willSleep`, `screensDidSleep`, `locked`, `screensaverStarted`, `sessionResigned`) and
/// `displayRemoved` are delivered to every controller synchronously, before the coalesced re-reduction (§4.1).
public nonisolated enum SystemEvent: Hashable, Sendable {
    /// The system is about to sleep (shield).
    case willSleep
    /// The system woke.
    case didWake
    /// The displays went to sleep (shield).
    case screensDidSleep
    /// The displays woke.
    case screensDidWake
    /// The screen locked (shield).
    case locked
    /// The screen unlocked.
    case unlocked
    /// The screensaver started (shield).
    case screensaverStarted
    /// The screensaver stopped.
    case screensaverStopped
    /// Our session left the console (shield; fast user switching).
    case sessionResigned
    /// Our session is on the console again.
    case sessionBecameActive
    /// Begin-phase callback: overlays go to factor 1, nothing else.
    case displayConfigurationBegan
    /// Remove flag: immediate, not debounced (§4.3).
    case displayRemoved(CGDirectDisplayID)
    /// Debounced after-phase pass (0.5 s, confirmed at 2 s).
    case displaysReconfigured
    /// `NSApplication.didChangeScreenParametersNotification` (also on H changes).
    case screenParametersChanged
    /// Distributed ColorSync display-profile notification.
    case colorProfileChanged
    /// Accessibility display options changed (invert, contrast, …).
    case accessibilityDisplayOptionsChanged
    /// The active Space changed.
    case activeSpaceChanged
    /// An app became frontmost.
    case appActivated(bundleID: String?)
    /// An app launched.
    case appLaunched(bundleID: String?)
    /// An app quit: any table writer's death resets every display (§4.8).
    case appTerminated(bundleID: String?, processID: Int32)
    /// macOS 26+ asked apps to suppress HDR.
    case hdrSuppressionBegan
    /// The HDR suppression ended.
    case hdrSuppressionEnded
    /// The thermal state changed.
    case thermalChanged(ThermalLevel)
    /// The power source, battery percent or Low Power Mode changed.
    case powerChanged
}
