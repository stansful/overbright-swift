// OverbrightPolicy/OverbrightPolicy.swift — module overview. ARCHITECTURE.md §2.1, §3.10, §5, §6, §7.2.
//
// Pure decisions (nonisolated, Foundation + Core only; no clocks, no I/O, no randomness, no strings):
//   Math/          FactorMath, LevelMapping, StepMath, PresetVisibility (WP0a)
//   Ceilings/      GainCeiling: liveCap and the helpers (WP0a), sliderTop and the SDR maximum (WP1)
//   Domain/        TransferDomainResolver, CompatibilityModels (WP0a)
//   Tables/        TableClassifier: matchesBase / scaled / foreign / invalid against the profile base (D26)
//   Eligibility/   EligibilityClassifier: verdict, advisories and class defaults (D8)
//   Reducer/       BoostPolicy.reduce (D10, §6): DisplayReducer per display, BannerSelector, SymbolSelector
//   Readout/       ReadoutValues and Readout: the numbers behind a card's readout (DESIGN.md §5.6)
//   Conflicts/     ConflictMatcher and ConflictCatalog.swift (the D3 path-allowlisted file)
// User-facing names and sentences of these values live in OverbrightDesign (D23).
