// OverbrightTriggers — the EDR trigger windows. ARCHITECTURE.md D4, D22, §2.1 rule 6, §4.7, §7.6, §10.5. Thread: main
// (AppKit windows, Core Animation, Metal layers); HLG still encoding and verification run off the main actor in
// `@concurrent` functions (§8.1 rule 3).
//
// What lives here:
// - `SystemTriggerFactory` (public): the real `TriggerFactory` and a `ServiceLifecycle`; counts open windows for
//   diagnostics (`triggerWindows`).
// - The ladder's strategies, one handle type each: T1 `TaggedLayerTrigger`, T2/T3 `MetalClearTrigger`, T4
//   `HLGStillTrigger` (over our own runtime-generated `HLGStillAsset`) and T4-alt `HLGSampleBufferTrigger`.
// - The window recipe (`WindowRecipes`), the window owner (`TriggerHost`), the pure geometry (`TriggerGeometry`) and
//   the EDR colour builders (`TaggedColor`).
//
// Rules this module keeps: no `.metal` file and no Metal library, function or pipeline API (a clear-only pass needs
// none, D22); EDR colours start from `CGColor`, never from `NSColor`'s component initialiser (§4.7); only
// `SystemWindowPresenter` orders a window in, and tests never construct it; zero work until the engine arms a rung;
// errors reach `.public` logs only as `LoggedError` summaries, never as descriptions that can hold a path (§9.2 rule 8).
