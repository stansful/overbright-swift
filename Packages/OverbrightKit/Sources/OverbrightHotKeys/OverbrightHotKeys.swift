// OverbrightHotKeys — module overview. ARCHITECTURE.md §2.1 (L1: Core and Policy only), §3.6 (`ShortcutCenter`),
// §3.7, D17; DESIGN.md §7.6, §16. Ported from Cranny's HotKeyCenter (the owner's MIT code) by WP0b.
//
//   HotKeyCenter.swift            the `ShortcutCenter` and `ServiceLifecycle`: registers every shortcut of
//                                 `ShortcutCatalog` with its effective binding (`ShortcutSettings.bindings`), re-applies
//                                 on every change, pauses while the Settings recorder listens, and renders key caps in
//                                 the current keyboard layout (`displayString`).
//   HotKeyRegistrar.swift         the slice of Carbon the center uses, behind a protocol (tests register nothing real).
//   CarbonHotKeyRegistrar.swift   `RegisterEventHotKey` on the application event target, signature 'OVBR': no
//                                 Accessibility permission (verified on macOS 27 in Cranny).
//
// The module knows no actions: the composition root hands `HotKeyCenter.onPress` the engine's calls (WP13), since an
// L1 module never imports another one.
