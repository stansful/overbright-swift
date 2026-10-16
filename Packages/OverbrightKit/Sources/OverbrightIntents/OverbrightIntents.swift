// OverbrightIntents — the App Intents router, the Focus filter sink and the control state publisher.
// ARCHITECTURE.md §7.7, §10.10, D18, D25. Layer 1: Core, Policy and the Foundation-only OverbrightChannel only.
//
// - `IntentRouter` (Router/): the logic behind the app target's one-line App Intents adapters (`App/Intents/`) and the
//   shared control intent (`Shared/BoostControlIntent.swift`): the readiness wait, every intent in canonical units, the
//   Focus sink with its launch-time read, the `overbright://control` hand-off, Get State's dialog and the display
//   choices. The declarations stay in the app target, because extracted intent metadata is localized against the
//   bundle that carries it and an `AppShortcutsProvider` in a package is dropped (D18).
// - `ControlStatePublisher` (Control/): the one publish point of the dormant control's state (D25); a no-op unless the
//   build ships the extension (`CONTROLS=1`).
