// OverbrightBoostTests/Fakes/CountingGammaPort.swift — a GammaPort decorator over FakeGammaPort that counts
// `profileBase` calls and logs every read with its time, so tests can tell how often the engine asks for the expected
// base (ARCHITECTURE.md §4.8 step 1) and when its drift ticks read the table (§4.8, D29). Test-only; Core's fake is
// unchanged. Nonisolated and lock-protected like the port it wraps.
import CoreGraphics
import Foundation
import OverbrightCore

/// Forwards everything to `inner`; counts `profileBase(of:count:)` and logs `read(_:)`.
nonisolated final class CountingGammaPort: GammaPort, @unchecked Sendable {
    /// One table read: which display, when (`time.now`).
    struct Read: Hashable, Sendable {
        let display: CGDirectDisplayID
        let time: MonotonicInstant
    }

    let inner: FakeGammaPort
    let time: any TimeSource
    private let lock = NSLock()
    private var profileBaseCalls = 0
    private var readLog: [Read] = []

    /// A decorator over `inner` whose read log is stamped by `time`.
    init(_ inner: FakeGammaPort, time: any TimeSource) {
        self.inner = inner
        self.time = time
    }

    /// `profileBase` calls since the last `resetCounts()`.
    var profileBaseCount: Int { lock.withLock { profileBaseCalls } }
    /// Reads since the last `resetCounts()`, in order.
    var reads: [Read] { lock.withLock { readLog } }
    /// Starts counting afresh.
    func resetCounts() { lock.withLock { profileBaseCalls = 0; readLog = [] } }

    // MARK: GammaPort

    func capacity(of display: CGDirectDisplayID) -> Int { inner.capacity(of: display) }

    func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        let now = time.now
        lock.withLock { readLog.append(Read(display: display, time: now)) }
        return try inner.read(display)
    }

    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        lock.withLock { profileBaseCalls += 1 }
        return inner.profileBase(of: display, count: count)
    }

    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws { try inner.write(table, to: display) }

    func restoreSystemColorSettings() { inner.restoreSystemColorSettings() }

    var writeCount: Int { inner.writeCount }
}
