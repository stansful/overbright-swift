// OverbrightCore/Services/RingBufferJournal.swift — the diagnostics journal: an in-memory ring of the last 500 events.
// ARCHITECTURE.md §3.6, §8.3.
import Foundation

/// The real `DiagnosticsJournal`: the last `capacity` events in memory (codes, display keys and numbers only; never
/// names or paths). Nonisolated and lock-protected, so the hang watchdog and the signal queue can record too.
/// `@unchecked Sendable`: every stored property is behind `lock`.
public nonisolated final class RingBufferJournal: DiagnosticsJournal, @unchecked Sendable {
    /// The number of events kept (§8.3: 500).
    public let capacity: Int
    private let lock = NSLock()
    private var events: [JournalEvent] = []
    private var next = 0

    /// A journal keeping the last `capacity` events (at least 1).
    public init(capacity: Int = 500) {
        self.capacity = max(capacity, 1)
        events.reserveCapacity(self.capacity)
    }

    /// Appends `event`, dropping the oldest when full.
    public func record(_ event: JournalEvent) {
        lock.withLock {
            if events.count < capacity {
                events.append(event)
            } else {
                events[next] = event
            }
            next = (next + 1) % capacity
        }
    }

    /// Every kept event, oldest first.
    public func snapshot() -> [JournalEvent] {
        lock.withLock {
            events.count < capacity ? events : Array(events[next...] + events[..<next])
        }
    }
}
