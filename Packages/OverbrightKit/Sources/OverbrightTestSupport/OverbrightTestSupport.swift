// OverbrightTestSupport/OverbrightTestSupport.swift — module overview. ARCHITECTURE.md §2.1, §9.1, §10.1.
//
// Test helpers for the test targets only (never linked into the app; no Resources folder):
//   SeededGenerator    reproducible randomness for property tests (§9.1)
//   ReferenceReducer   a tiny stand-in for BoostPolicy.reduce, so WP4 tests the engine before WP1 lands (§10.1)
//   eventually(_:)     the one real-time wait tests may use, with a generous 30 s bound (§9.1)
//   SampleShortcuts    combinations tests bind, since every global shortcut ships unbound (D17)
// Core's Fakes/ hold the port fakes and display fixtures (they are public there because #Previews and
// `--qa-simulate` use them too).
