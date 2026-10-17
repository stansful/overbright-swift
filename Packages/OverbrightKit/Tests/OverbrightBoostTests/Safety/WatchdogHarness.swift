// OverbrightBoostTests/Safety/WatchdogHarness.swift — a scaled display in a ledger, a writer, and a queue that stands in
// for the main thread and can be stalled. ARCHITECTURE.md §4.6, §7.4 (hang watchdog, signal handlers).
import CoreGraphics
import Dispatch
import Foundation
import OverbrightCore
@testable import OverbrightBoost

/// The ports behind the hang watchdog and the signal handlers: display 1 scaled ×1.3 over an identity base, recorded
/// in the ledger as it would be while boosted.
nonisolated final class WatchdogHarness: Sendable {
    let gamma = FakeGammaPort()
    let ledger = SafetyLedger()
    let journal = RingBufferJournal()
    /// The writer's time source: the hang watchdog's ping grid follows it (D29); it moves only when a test says so.
    let time = ManualTimeSource()
    let writer: TableWriter
    let base = GammaTable.identity(count: 256)
    let display = DisplayRef(key: DisplayFixture.Keys.builtIn, id: 1)
    /// Stands in for the main queue; `stall()` blocks it.
    let pinged = DispatchQueue(label: "app.overbright.tests.pinged")

    init() {
        gamma.addDisplay(1, base: base, table: base.scaled(by: 1.3))
        writer = TableWriter(gamma: gamma, ledger: ledger, time: time, journal: journal)
        ledger.markScaled(display, baseline: base)
    }

    /// A watchdog pinging `queue` (default: the stallable test queue).
    func watchdog(ping: Duration, timeout: Duration, queue: DispatchQueue? = nil) -> HangWatchdog {
        HangWatchdog(writer: writer, ledger: ledger, journal: journal, pingInterval: ping, timeout: timeout,
                     pinged: queue ?? pinged)
    }

    /// Blocks the pinged queue until the stall is released.
    func stall() -> Stall {
        let stall = Stall()
        pinged.async { stall.begin() }
        return stall
    }

    /// Journal codes so far.
    var codes: [String] { journal.snapshot().map(\.code) }
}

/// A queue stall: `begin()` runs on the stalled queue and blocks it until `release()`.
nonisolated final class Stall: Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let started = LockedState<UInt64?>(nil)

    /// Uptime (ns) at which the queue stopped answering.
    var startedAt: UInt64? { started.withLock { $0 } }

    func begin() {
        started.withLock { $0 = DispatchTime.now().uptimeNanoseconds }
        gate.wait()
    }

    func release() { gate.signal() }
}

/// Whether `TableWriter.writeBaselines(fromLedger:)` is WP4's body rather than the WP0a seed (which writes nothing).
nonisolated enum TableWriterProbe {
    /// True once a ledger baseline reaches the gamma port.
    static var writesBaselines: Bool {
        let gamma = FakeGammaPort()
        let base = GammaTable.identity(count: 8)
        gamma.addDisplay(9, base: base, table: base.scaled(by: 1.2))
        let ledger = SafetyLedger()
        let writer = TableWriter(gamma: gamma, ledger: ledger, time: ManualTimeSource(), journal: RingBufferJournal())
        ledger.markScaled(DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000FF"), id: 9),
                          baseline: base)
        let written = ledger.withLock { writer.writeBaselines(fromLedger: $0) }
        return written == 1 && gamma.table(of: 9) == base
    }
}

/// Polls `condition` every 10 ms for at most `timeout` from any thread (the watchdog and signal tests wait for
/// background queues, not for main-actor scheduling).
nonisolated func waitUntil(_ timeout: Duration, _ condition: @Sendable () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

/// Seconds between two uptimes in nanoseconds.
nonisolated func seconds(from start: UInt64, to end: UInt64) -> Double {
    Double(Int64(bitPattern: end &- start)) / 1_000_000_000
}
