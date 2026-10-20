// OverbrightAppShell — the composition root, the status item, the panel's window, the HUD and every other window.
// ARCHITECTURE.md §2.1 (L3), §3.9, §7.4, §7.6, §10.0, §10.15.
//
//   App/         `AppDelegate` (a thin orchestrator), `CompositionRoot` (the only place that knows concrete types: real
//                or `--qa-simulate` ports, `ShellContext`, `ShellPorts`, `Shell`), the launch order and the quit
//                (`LaunchSequence`, `ServiceStack`, `ServiceRunner`, `QuitFlow`), `DiagnosticsReport`, what each global
//                shortcut does, and the DEBUG-only QA hooks and scripted scenarios
//   Launch/      single instance (D27), the one `UserDefaults` (`ShellDefaults`, a QA suite in DEBUG), the launch gate,
//                "Move to Applications?"
//   StatusItem/  the `NSStatusItem` and its symbol drawn in code, what a click does (`ClickRouting`), the right-click
//                menu as data and as an `NSMenu`, the icon visibility check and the icon-not-visible window
//   Panel/       the panel's borderless non-activating `NSPanel`, its placement under the status item and its container
//   HUD/         the level indicator (`HUDController`, `HUDPolicy`, `HUDView`) and "Keep this level?", sharing one slot
//                at the bottom of a display
//   Windows/     Settings, Welcome and calibration windows, and the self-test's Save Log… panel
//   Help/, Dock/, LoginItem/, Services/
//                the Help window, the optional Dock icon's menu, opening at login, and `ShellAppControl` (the shell's
//                `AppControl`), the status icon's presence and the controls' publish point
//
// Layer 3: imports Core, Policy, Design, Channel, every L1 module and the L2 UI modules (§2.1). Only the app target
// imports it: `App/OverbrightApp.swift` adopts `AppDelegate` and shows `OverbrightScenes`.
