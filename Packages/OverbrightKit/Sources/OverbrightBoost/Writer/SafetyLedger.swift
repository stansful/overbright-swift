// OverbrightBoost/Writer/SafetyLedger.swift — what must be restored if the main thread hangs or a signal arrives.
// ARCHITECTURE.md §4.1, §4.5 invariant 9, §4.6, §7.4, §8.1 rule 4; D7.
// Seeded by WP0a with the fixed signatures (§10.0) and a minimal working body; owned by WP4.
// Nonisolated and lock-protected: the hang watchdog's queue and the signal queue use it off the main actor. An
// `NSLock` (not an unfair lock), because `TableWriter` holds it across a WindowServer call.
import Foundation
import OverbrightCore

/// Per display: the captured baseline while the display is scaled or dimmed; plus the process-wide hang epoch.
/// `@unchecked Sendable`: every stored property is behind `lock` (§8.1 rule 7).
public nonisolated final class SafetyLedger: @unchecked Sendable {
    /// One display that is scaled or dimmed.
    public struct Entry: Hashable, Sendable {
        /// The display (its CoreGraphics ID is what a baseline write needs).
        public var display: DisplayRef
        /// The table to write back.
        public var baseline: GammaTable
        /// An entry.
        public init(display: DisplayRef, baseline: GammaTable) { self.display = display; self.baseline = baseline }
    }

    /// Everything behind the lock; `withLock(_:)` hands it out.
    public struct State: Sendable {
        /// Displays that are scaled or dimmed, by key.
        public var entries: [DisplayKey: Entry]
        /// Bumped by the hang watchdog; `TableWriter` refuses scaled writes stamped with an older epoch (§4.6).
        public var hangEpoch: UInt64
        /// An empty ledger at epoch 0.
        public init(entries: [DisplayKey: Entry] = [:], hangEpoch: UInt64 = 0) {
            self.entries = entries; self.hangEpoch = hangEpoch
        }
    }

    private let lock = NSLock()
    private var state = State()
    private var occupancyObserver: (@Sendable (Bool) -> Void)?

    /// An empty ledger.
    public init() {}

    /// Runs `body` with the state while holding the ledger lock. `TableWriter` holds it across each write, and the
    /// hang watchdog across its epoch bump and baseline writes, so writes land in lock order (§4.6). Never call another
    /// ledger method inside `body` (the lock is not recursive). When `body` takes the ledger from empty to occupied or
    /// back, the occupancy observer runs before the lock is released.
    public func withLock<T>(_ body: (inout State) throws -> T) rethrows -> T {
        lock.lock()
        let wasOccupied = !state.entries.isEmpty
        defer {
            let isOccupied = !state.entries.isEmpty
            if isOccupied != wasOccupied { occupancyObserver?(isOccupied) }
            lock.unlock()
        }
        return try body(&state)
    }

    /// Calls `observer` whenever the ledger goes from empty to occupied (`true`) or back (`false`), and once now with
    /// the current occupancy; nil stops it. The engine arms its hang watchdog with it (D7): whatever path marks a display
    /// (a ramp step, a dim, a calibration factor), the watchdog runs from that write on, and the restore that empties
    /// the ledger switches it off. It runs on the thread of the change, **inside the ledger lock**, so occupancy and the
    /// observer's reaction never interleave with another change; it must never use the ledger.
    public func observeOccupancy(_ observer: (@Sendable (Bool) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        occupancyObserver = observer
        observer?(!state.entries.isEmpty)
    }

    /// The current hang epoch.
    public var hangEpoch: UInt64 { withLock { $0.hangEpoch } }

    /// Records `display` as scaled or dimmed with `baseline` (before the scaled write is issued, §4.5 invariant 9).
    public func markScaled(_ display: DisplayRef, baseline: GammaTable) {
        withLock { $0.entries[display.key] = Entry(display: display, baseline: baseline) }
    }

    /// Forgets `display` (after its baseline write returned, or when the display is gone).
    public func unmark(_ display: DisplayKey) {
        withLock { $0.entries[display] = nil }
    }

    /// Every entry, ordered by display key.
    public func entries() -> [Entry] {
        withLock { $0.entries.values.sorted { $0.display.key < $1.display.key } }
    }

    /// Whether `display` is recorded as scaled or dimmed.
    public func isMarked(_ display: DisplayKey) -> Bool { withLock { $0.entries[display] != nil } }

    /// The displays recorded as scaled or dimmed.
    public var markedDisplays: Set<DisplayKey> { withLock { Set($0.entries.keys) } }
}
