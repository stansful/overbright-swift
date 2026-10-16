// OverbrightCore/Model/Engine/RescueOutcome.swift — what the launch rescue or Reset Display Colors did. ARCHITECTURE.md §3.5, §7.4.

/// What the launch rescue, `--restore-gamma` or Advanced ▸ Reset Display Colors did (D7).
public nonisolated enum RescueOutcome: Hashable, Sendable {
    /// Every table matched its base: nothing to do.
    case alreadyNeutral
    /// The global restore neutralized this many displays.
    case restored(displays: Int)
    /// The global restore left an invalid table (e.g. all zeros); the profile base was written explicitly.
    case repairedInvalidRestore(displays: [DisplayKey])
    /// A catalogued table writer runs: rescue skipped.
    case skippedBecauseTableWriterRuns(ConflictingApp)
    /// Our session is not on the console (D27).
    case skippedNotOnConsole
    /// A session-level foreign write: preset change, logout or reboot.
    case residueRemains(displays: [DisplayKey])
}
