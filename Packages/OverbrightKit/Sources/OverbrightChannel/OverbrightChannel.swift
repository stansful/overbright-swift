// OverbrightChannel — the Foundation-only state channel of the dormant Control Center control. ARCHITECTURE.md §7.7,
// §10.10, D25. Nonisolated, no Core: the sandboxed extension links this module and nothing else of OverbrightKit.
//
// What lives here (no App Group, ever):
// - `BoostChannel`: the notifyd state word (`pack` / `unpack`), the preferences snapshot the extension reads through
//   its read-only shared-preference exception, the `set=on` token, and the extension's pure decisions (the liveness
//   gate of the value provider, the wait after a hand-off);
// - `NotifyStateWord`: the notifyd name's 64-bit state (the app posts, the extension reads);
// - `ChannelStore` with `PreferencesChannelStore` (the app's own preferences domain) and `InMemoryChannelStore`
//   (tests and previews; nothing a test runs writes the real domain);
// - `URLRoute`: the `overbright://` parser, its inverse and the token check.
//
// The app's one publish point is `ControlStatePublisher` in OverbrightIntents; the URL handling is
// `IntentRouter.control(on:token:)`.
