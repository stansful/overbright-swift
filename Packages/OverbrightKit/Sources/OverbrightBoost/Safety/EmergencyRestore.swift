// OverbrightBoost/Safety/EmergencyRestore.swift — the one critical section the hang watchdog and the signal handlers run:
// bump the hang epoch, write every ledger baseline, forget the entries. ARCHITECTURE.md §4.6, §7.4, §8.1 rule 4; D7.
// Any thread (the watchdog's utility queue, the signal queue); touches displays only through
// `TableWriter.writeBaselines(fromLedger:)` (§4.5 invariant 3).
import OverbrightCore

/// Restores every scaled or dimmed display from the safety ledger, off the main actor.
nonisolated enum EmergencyRestore {
    /// What one restore did.
    struct Result: Hashable, Sendable {
        /// Baselines `TableWriter` wrote.
        var displays: Int
        /// The hang epoch after the bump.
        var epoch: UInt64
    }

    /// Under the ledger lock: increments the hang epoch (so `TableWriter` refuses every scaled write stamped before it,
    /// including writes queued behind a stall, until the engine re-gates), writes every ledger baseline through
    /// `writer`, and clears the entries (the displays are at their baselines now). A write already in flight holds the
    /// same lock, so it lands before the baselines.
    static func run(writer: TableWriter, ledger: SafetyLedger) -> Result {
        ledger.withLock { state in
            state.hangEpoch &+= 1
            let written = writer.writeBaselines(fromLedger: state)
            state.entries.removeAll()
            return Result(displays: written, epoch: state.hangEpoch)
        }
    }
}
