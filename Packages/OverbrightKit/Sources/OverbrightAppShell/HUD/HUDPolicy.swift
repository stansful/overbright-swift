// OverbrightAppShell/HUD/HUDPolicy.swift — when the HUD shows, for how long, and how VoiceOver hears it. DESIGN.md §6
// ("When": shortcuts, the Shortcuts app, a Focus filter and Back to Standard from anywhere, the Dock menu included;
// "Preparing…" for icon, shortcut and Shortcuts turn-ons, held until the display is ready; blocked requests;
// automation stops, caps and resumes; never for the panel, the menu or Settings, never for full-screen, app or game
// pauses; 1.5 s, 3 s for automation reasons; never two), §12.7 and §15 (announcements: the user's own changes never
// rate-limited, automations at most one per 10 s, and spoken whether or not the HUD's window shows: General ▸ Show
// level changes on screen turns the window off, not VoiceOver), D19; ARCHITECTURE.md §4.9 (`status.lastChange` by
// its increasing `sequence`; the engine publishes `.level` only for a shortcut, an intent, a Focus or Back to
// Standard, so a `.level` change from any other source is a Back to Standard). Pure, for `HUDPolicyTests`.
import OverbrightCore

/// The HUD's rules.
enum HUDPolicy {
    /// What one change shows.
    struct Presentation: Equatable {
        /// How long the HUD stays after this change.
        let duration: Duration
        /// How the announcement is rate-limited (`Announcer.Kind`).
        let announcement: Announcer.Kind
        /// The window shows (General ▸ Show level changes on screen); VoiceOver hears the change either way.
        let showsWindow: Bool

        init(duration: Duration, announcement: Announcer.Kind, showsWindow: Bool = true) {
            self.duration = duration; self.announcement = announcement; self.showsWindow = showsWindow
        }
    }

    /// The HUD's stay after a level change.
    static let levelDuration: Duration = .milliseconds(1500)
    /// The HUD's stay after an automation reason.
    static let automationDuration: Duration = .seconds(3)
    /// The longest "Preparing…" waits for the display before the HUD shows the level reached (DESIGN.md §3.3: a raise
    /// arrives within 3 s).
    static let preparingLimit: Duration = .seconds(3)

    /// The presentation of `change`, or nil when it is neither shown nor spoken: a change already handled
    /// (`sequence` not above `lastShown`), a change made where the user sees its result anyway, or a pause the user
    /// caused. `showsHUD` (General ▸ Show level changes on screen) decides only the window.
    static func presentation(for change: LevelChange, lastShown: UInt64?, showsHUD: Bool) -> Presentation? {
        if let lastShown, change.sequence <= lastShown { return nil }
        func shown(_ duration: Duration, _ announcement: Announcer.Kind) -> Presentation {
            Presentation(duration: duration, announcement: announcement, showsWindow: showsHUD)
        }
        switch change.kind {
        case .level:
            switch change.source {
            case .intent, .focusFilter: return shown(levelDuration, .result)
            case .automation, .launch: return nil                       // Overbright's own changes have their kinds
            // A shortcut; any other source is a Back to Standard (the Dock menu's), the user's own action.
            case .shortcut, .panel, .menu, .settings, .welcome, .statusItem: return shown(levelDuration, .feedback)
            }
        case .preparing, .blocked:
            switch change.source {
            case .statusItem, .shortcut: return shown(levelDuration, .feedback)
            case .intent, .focusFilter: return shown(levelDuration, .result)
            default: return nil
            }
        case .automationStopped(let reason):
            guard isAutomation(reason) else { return nil }
            return shown(automationDuration, .alert)
        case .automationResumed, .timerEnded:
            return shown(automationDuration, .alert)
        }
    }

    /// Reasons an automation stops or caps the boost on its own (timer, battery, Low Power, heat, schedule); never the
    /// full-screen, app, game or idle pauses the user caused.
    static func isAutomation(_ reason: LimitReason) -> Bool {
        switch reason {
        case .battery, .onBattery, .lowPowerMode, .thermalSerious, .thermalCritical, .outsideSchedule: true
        default: false
        }
    }

    /// Some display of `status` is preparing (arming or gating): a turn-on's "Preparing…" stays up meanwhile.
    static func isPreparing(_ status: BoostStatus, display: DisplayKey?) -> Bool {
        status.isOn && status.displays.contains { shown in
            guard display == nil || shown.key == display else { return false }
            switch shown.phase {
            case .arming, .gating: return true
            default: return false
            }
        }
    }
}
