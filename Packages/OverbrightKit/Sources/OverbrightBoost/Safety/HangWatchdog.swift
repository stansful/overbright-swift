// OverbrightBoost/Safety/HangWatchdog.swift — restores the displays when the main thread stalls while scaled.
// ARCHITECTURE.md §4.6, §7.4, §8.1 rules 2 and 4; D7. Thread: its own utility queue (a `DispatchSourceTimer`, the one
// sanctioned repeating timer), never the main actor; it touches displays only through
// `TableWriter.writeBaselines(fromLedger:)` under the ledger lock, and never calls `DispatchQueue.main.sync`.
// Seeded by WP0a with the fixed signatures (§10.0); owned by WP5 (body, `HangWatchdogTests` under TSan,
// `HangWatchdogOffMainTests`). The WP0a body starts no timer.
import OverbrightCore

/// Ping-pong with the main thread every 2 s while any display is scaled; a ping unanswered for 3 s bumps the hang
/// epoch and writes every ledger baseline, then records that it fired.
public nonisolated final class HangWatchdog: Sendable {
    private let writer: TableWriter
    private let ledger: SafetyLedger
    private let journal: any DiagnosticsJournal

    /// A watchdog writing through `writer` from `ledger`.
    public init(writer: TableWriter, ledger: SafetyLedger, journal: any DiagnosticsJournal) {
        self.writer = writer; self.ledger = ledger; self.journal = journal
    }

    /// Runs while any display is scaled or dimmed (the engine switches it). WP0a seed: does nothing.
    public func setActive(_ active: Bool) { _ = active }

    /// Whether the watchdog fired since the last call (the engine then journals `hang.restored` and re-gates).
    /// WP0a seed: never.
    public func consumeFiredFlag() -> Bool { false }
}
