// OverbrightAppShell/App/LaunchStep.swift — the launch steps of ARCHITECTURE.md §7.4, in order (`LaunchSequence` runs
// them; `LaunchOrderTests` checks the order).

/// The launch steps, in order.
enum LaunchStep: String, CaseIterable {
    /// A Release build refuses Debug-only switches (§8.5).
    case refuseDebugSwitches
    /// `ShellDefaults`, then the composition root's hub (no I/O).
    case servicesHub
    /// `--diagnostics`, `--monitor`, `--restore-gamma`: run and quit.
    case commandLineModes
    /// D27: another Overbright runs → hand over and quit.
    case singleInstance
    /// DESIGN.md §12.4.
    case moveToApplications
    /// `SettingsUpgrades`, once per install and revision.
    case settingsUpgrade
    /// The controllers, the router connection, the status item, the Dock and the HUD.
    case controllers
    /// `LaunchGate`: the launch check, then every service.
    case launchWork
    /// Debug QA hooks.
    case qaHooks
    /// What the launch shows (§7.6).
    case launchUI
}
