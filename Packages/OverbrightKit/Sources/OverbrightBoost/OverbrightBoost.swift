// OverbrightBoost — the per-display engine behind `BoostControl`, its safety net and its instruments. ARCHITECTURE.md
// §4, §5, §7.4, §8.4, §10.6, §10.7; D5, D6, D7, D9.
//
//   Engine/      `BoostEngine` (requests, system events, the policy loop, status publication, "Keep this level?") and
//                one `DisplayController` per online display (arming, the gate, ramps, the drift check, re-basing, write
//                failures), with the pure rules they use: `GateEvaluator`, `RampPlanner`, `DriftCheck`, `FlickerGuard`,
//                `BaselineRules`, `SDRWhiteSource`
//   Writer/      `TableWriter`, the interlock and the only code that writes a scaled table (§4.5 invariants 1 and 3),
//                the `SafetyLedger` and the journal codes
//   Ladder/      the trigger ladder: which rungs a display tries (`LadderPlanner`) and what the `StrategyCache` learned
//   Safety/      the launch check and rescue, the hang watchdog, TERM/INT/HUP handlers and their one critical section
//   SelfTest/    Advanced ▸ Run Self-Test (`SelfTestRunner`, `HeadroomTrace`, `MeasurementLadder`)
//   Calibration/ one running calibration (`CalibrationController`), its step wedge and decision rule
//   Shared/      `EngineTiming` (every timing and threshold constant, §4.4) and the seam the instruments drive
//
// Layer 1: imports OverbrightCore, OverbrightPolicy and Apple frameworks only (§2.1). Every port (gamma, headroom,
// triggers, signals, conflicts, time) is injected, so the whole engine runs on fakes in tests.
