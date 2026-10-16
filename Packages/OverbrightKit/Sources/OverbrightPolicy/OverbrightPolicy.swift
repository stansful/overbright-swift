// OverbrightPolicy/OverbrightPolicy.swift — module overview. ARCHITECTURE.md §2.1, §3.10, §5, §6.
//
// Pure decisions (nonisolated, Foundation + Core only; no clocks, no I/O, no randomness, no strings):
//   Math/          FactorMath, LevelMapping, StepMath, PresetVisibility (real bodies since WP0a)
//   Ceilings/      GainCeiling (liveCap and the small helpers are real since WP0a; sliderTop is WP1's)
//   Domain/        TransferDomainResolver, CompatibilityModels (real since WP0a)
//   Tables/        TableClassifier (WP1)
//   Eligibility/   EligibilityClassifier (WP1)
//   Reducer/       BoostPolicy.reduce (WP1)
//   Readout/       ReadoutValues and Readout (WP1)
//   Conflicts/     ConflictMatcher (WP1) and ConflictCatalog.swift (WP1; the D3 path-allowlisted file)
// WP0a ships the signatures of §3.10 with the small math bodies as written there; WP1 implements the stubs.
