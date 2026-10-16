// OverbrightCore/Ports/DiagnosticsJournal.swift — the diagnostics journal. ARCHITECTURE.md §3.6, §8.3.
// Real: `RingBufferJournal` (Services/). Contract rule (§10.0): a requirement added after WP0a lands only together
// with a default implementation in a protocol extension in this file.

/// In-memory ring buffer (last 500 events) behind self-test logs and Copy Diagnostics.
public protocol DiagnosticsJournal: Sendable {
    /// Appends an event (the oldest is dropped when full).
    func record(_ event: JournalEvent)
    /// Every kept event, oldest first.
    func snapshot() -> [JournalEvent]
}
