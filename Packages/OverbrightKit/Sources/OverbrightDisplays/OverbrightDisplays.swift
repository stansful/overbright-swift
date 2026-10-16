// OverbrightDisplays — the display directory, headroom and gamma ports (layer 1; Core and Policy only).
// ARCHITECTURE.md §2.1, §3.6, §7.1, §10.4; D7, D8, D9, D24, D26.
//
// - `Directory/`: `SystemDisplayDirectory` (the real `DisplayDirectory`: online list, `DisplayKey.of`, built-in first,
//   the reconfiguration callback with an immediate remove and a debounced after phase, clamshell and mirror rules),
//   its model, pipeline and C callback, and the pure `DisplayFactsBuilder` / `PanelClassifier`.
// - `Registry/`: `IORegistryFacts` (built-in `EDRPotentialHeadroom`, `user-accessible-max-nits`; externals'
//   `DisplayAttributes` luminance, PQ support and product IDs; the lid state), read off the main actor.
// - `Headroom/`: `SystemHeadroomPort` (a fresh NSScreen per read; nil for mirror members).
// - `Gamma/`: `CoreGraphicsGamma` (the ONLY file with the CoreGraphics table setters and the global restore),
//   `ProfileVCGT` / `ProfileBase` (the expected base from the profile's `vcgt`, D26) and `GammaWriteGate`.
// - `Monitor/`: the read-only `--monitor` loop.
// No code here compares display names (D8); real ports run in tests only behind `OVERBRIGHT_HARDWARE=1`, read-only.
