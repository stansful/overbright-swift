// OverbrightSignals/Monitor/SignalSource.swift — the sources `SignalsMonitor` runs, by energy class. ARCHITECTURE.md
// §7.1 ("boost-only" sources run only while a display is scaled or dimmed), D22, DESIGN.md §17 (off: event
// notifications only; no timers, tasks or IOPS percent source).
// Thread: any (a value type). `SignalsMonitor.activeSources` lists the running ones; the energy test enumerates them in
// every state.

/// One source of system signals.
public nonisolated enum SignalSource: String, Sendable, CaseIterable {
    /// Workspace notifications: sleep and wake, screens, session, Space, app activation, launch and termination,
    /// accessibility options, and the KVO of the running-application list (the launches and terminations of agent and
    /// accessory apps, which post no notification). Always on.
    case workspaceNotifications
    /// Distributed notifications: lock and unlock, screensaver, ColorSync display profiles. Always on.
    case distributedNotifications
    /// Process notifications: screen parameters, thermal state, Low Power Mode (any thread), HDR suppression. Always on.
    case processNotifications
    /// IOKit's source-switch notification (adapter ↔ battery). Always on: it fires only on a switch.
    case powerSourceSwitch
    /// CoreMediaIO listeners, while Fill Light's camera rule is on (listeners, no polling).
    case camera
    /// IOKit's every-change notification for the battery percent: boost-only, on battery only, never while shielded.
    case batteryPercent
    /// One deadline for the OLED idle pause (`threshold − idle`, then every 2 s while idle): boost-only, OLED only.
    /// Once idle, the 2 s input poll outlasts the boost until input returns (the pause itself ends the boost). Never
    /// while shielded: the pause is kept and the idle time read again when the shield lifts.
    case idleDeadline
    /// The 2 s full-screen and playback re-check (catches borderless games and players starting or stopping):
    /// boost-only, while a full-screen or "while playing" rule is on, never while shielded.
    case fullScreenWatch
    /// One sleep towards the next schedule boundary: boost-only, while a schedule is set.
    case scheduleBoundary

    /// Event-driven sources that run whenever Signals runs (they cost nothing until the system posts something).
    public var isAlwaysOn: Bool {
        switch self {
        case .workspaceNotifications, .distributedNotifications, .processNotifications, .powerSourceSwitch: true
        case .camera, .batteryPercent, .idleDeadline, .fullScreenWatch, .scheduleBoundary: false
        }
    }

    /// Sources that run only while the boost is active (`SystemSignals.setBoostActive(true)`).
    public var isBoostOnly: Bool {
        switch self {
        case .batteryPercent, .idleDeadline, .fullScreenWatch, .scheduleBoundary: true
        case .workspaceNotifications, .distributedNotifications, .processNotifications, .powerSourceSwitch, .camera: false
        }
    }
}
