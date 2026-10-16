// OverbrightAppShell/HUD/HUDPolicy.swift — when the HUD shows, for how long, and how VoiceOver hears it. DESIGN.md §6
// ("When": shortcuts, the Shortcuts app, a Focus filter and Back to Standard; "Preparing…" for icon, shortcut and
// Shortcuts turn-ons; blocked requests; automation stops, caps and resumes; never for the panel, the menu or
// Settings, never for full-screen, app or game pauses; 1.5 s, 3 s for automation reasons; never two), §12.7
// (announcements: the user's own changes never rate-limited, automations at most one per 10 s), D19;
// ARCHITECTURE.md §4.9 (`status.lastChange` by its increasing `sequence`). Pure, for `HUDPolicyTests`.
import OverbrightCore

/// The HUD's rules.
enum HUDPolicy {
    /// What one change shows.
    struct Presentation: Equatable {
        /// How long the HUD stays after this change.
        let duration: Duration
        /// How the announcement is rate-limited (`Announcer.Kind`).
        let announcement: Announcer.Kind
    }

    /// The HUD's stay after a level change.
    static let levelDuration: Duration = .milliseconds(1500)
    /// The HUD's stay after an automation reason.
    static let automationDuration: Duration = .seconds(3)

    /// The presentation of `change`, or nil when the HUD shows nothing: a change already shown (`sequence` not above
    /// `lastShown`), the HUD turned off (General ▸ Show level changes on screen), a change made where the user sees its
    /// result anyway, or a pause the user caused.
    static func presentation(for change: LevelChange, lastShown: UInt64?, showsHUD: Bool) -> Presentation? {
        guard showsHUD else { return nil }
        if let lastShown, change.sequence <= lastShown { return nil }
        switch change.kind {
        case .level:
            switch change.source {
            case .shortcut: return Presentation(duration: levelDuration, announcement: .feedback)
            case .intent, .focusFilter: return Presentation(duration: levelDuration, announcement: .result)
            default: return nil
            }
        case .preparing, .blocked:
            switch change.source {
            case .statusItem, .shortcut: return Presentation(duration: levelDuration, announcement: .feedback)
            case .intent, .focusFilter: return Presentation(duration: levelDuration, announcement: .result)
            default: return nil
            }
        case .automationStopped(let reason):
            guard isAutomation(reason) else { return nil }
            return Presentation(duration: automationDuration, announcement: .alert)
        case .automationResumed, .timerEnded:
            return Presentation(duration: automationDuration, announcement: .alert)
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
}
