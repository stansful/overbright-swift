// OverbrightSettingsUI/Root/SettingsPaneID.swift — the seven panes of the Settings window. DESIGN.md §7.1, D15.
// Their raw values are the deep-link names `AppControl.openSettings("pane#row")`, `--qa-settings` and
// `overbright://settings/<pane>` use; never rename one that shipped.

/// A pane of the Settings window, in sidebar order.
public nonisolated enum SettingsPaneID: String, CaseIterable, Sendable {
    /// Startup, menu bar (with Quit), Dock, feedback, updates.
    case general
    /// All displays, then one section per display.
    case displays
    /// Battery, Low Power, heat, timer, apps and video, schedule, OLED idle, Focus.
    case automations
    /// Recorders, step size, Shortcuts app and Control Center.
    case shortcuts
    /// Preview, switch, display, width, warmth, brightness, camera rule.
    case fillLight
    /// Diagnostics, self-test, other apps, trigger method, recovery, Reset All with Undo.
    case advanced
    /// Version, updates, license, acknowledgements, privacy, Show Welcome.
    case about

    /// The pane a deep-link name stands for, ignoring case ("filllight" and "fillLight" both open Fill Light).
    public init?(link: String) {
        let folded = link.lowercased()
        guard let pane = Self.allCases.first(where: { $0.rawValue.lowercased() == folded }) else { return nil }
        self = pane
    }
}
