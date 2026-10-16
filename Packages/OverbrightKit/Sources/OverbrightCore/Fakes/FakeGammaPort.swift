// OverbrightCore/Fakes/FakeGammaPort.swift — an in-memory GammaPort with WindowServer's behaviours. ARCHITECTURE.md §3.9,
// §4.6, §4.8, §7.4, D7, D24, D26. Tests never construct a writing real port; this is the one they write to.
import CoreGraphics
import Foundation

/// A `GammaPort` that holds a table and a profile base per display behind a lock, records every write with a
/// timestamp, and simulates what WindowServer does: process death and another writer's death (every display back to
/// its base), foreign writes, profile/preset/HDR changes (`changeBase`), Macs that ignore writes, read-back that
/// clamps at 1.0, a global restore that writes zeros, and a write that blocks inside WindowServer.
/// `@unchecked Sendable`: every stored property is behind `lock`, as in the real port (§8.1 rule 4).
public nonisolated final class FakeGammaPort: GammaPort, @unchecked Sendable {
    /// One recorded write (ours or a simulated foreign one).
    public struct Write: Hashable, Sendable {
        /// The display written.
        public var display: CGDirectDisplayID
        /// The table as written (unclamped).
        public var table: GammaTable
        /// `TimeSource.now` when it landed.
        public var time: MonotonicInstant
        /// Written by `foreignWrite(_:to:)`, not through `write(_:to:)`.
        public var isForeign: Bool
    }

    private struct Display {
        var base: GammaTable?          // nil = no transfer table (capacity 0)
        var table: GammaTable?         // what WindowServer holds (and reads back)
        var screen: GammaTable?        // what is visible (differs while writes are ignored)
    }

    private let lock = NSLock()
    private let time: any TimeSource
    private var displays: [CGDirectDisplayID: Display] = [:]
    private var log: [Write] = []
    private var limit: Int?
    private var successfulWrites = 0
    private var restores = 0
    private var wroteATable = false
    private var ignoring = false
    private var clamping = false
    private var zeroRestore = false
    private var stall: DispatchSemaphore?
    private var stalled = false
    private var failure: GammaError?

    /// An empty port; add displays with `addDisplay(_:base:table:)`.
    public init(time: any TimeSource = ManualTimeSource()) { self.time = time }

    /// The displays of `fixture`, each at its profile base; ignores writes on the Mac of `.neoIgnoresWrites`.
    public convenience init(fixture: DisplayFixture, time: any TimeSource = ManualTimeSource()) {
        self.init(time: time)
        for display in fixture.displays {
            addDisplay(display.facts.ref.id, base: display.profileBase)
        }
        ignoresWrites = fixture.tableWritesIgnored
    }

    // MARK: Behaviour switches

    /// Writes succeed and read back correctly but change nothing on screen (`CompatibilityModels`, §7.5).
    public var ignoresWrites: Bool {
        get { lock.withLock { ignoring } }
        set { lock.withLock { ignoring = newValue } }
    }
    /// Read-back clamps entries above 1.0 (one of the two read-back models of D26).
    public var clampsReadBack: Bool {
        get { lock.withLock { clamping } }
        set { lock.withLock { clamping = newValue } }
    }
    /// `restoreSystemColorSettings()` leaves all-zero tables (the failed global restore of D7).
    public var restoreWritesZeros: Bool {
        get { lock.withLock { zeroRestore } }
        set { lock.withLock { zeroRestore = newValue } }
    }

    // MARK: Displays

    /// Adds a display whose profile base is `base` (nil = no transfer table) and whose live table is `table`
    /// (default: the base).
    public func addDisplay(_ id: CGDirectDisplayID, base: GammaTable?, table: GammaTable? = nil) {
        lock.withLock { displays[id] = Display(base: base, table: table ?? base, screen: table ?? base) }
    }
    /// The display is gone: every call for it fails with `.displayGone`.
    public func removeDisplay(_ id: CGDirectDisplayID) { lock.withLock { displays[id] = nil } }
    /// The live table, unclamped (what WindowServer holds).
    public func table(of id: CGDirectDisplayID) -> GammaTable? { lock.withLock { displays[id]?.table } }
    /// What the screen shows (differs from `table(of:)` only while writes are ignored).
    public func screenTable(of id: CGDirectDisplayID) -> GammaTable? { lock.withLock { displays[id]?.screen } }
    /// The display's profile base at its own length.
    public func base(of id: CGDirectDisplayID) -> GammaTable? { lock.withLock { displays[id]?.base } }

    // MARK: Records

    /// Every write in order, ours and foreign ones (the newest `recordLimit` when one is set).
    public var writes: [Write] { lock.withLock { log } }
    /// Keeps only about the newest `recordLimit` entries of `writes` (nil, the default: all of them). `--qa-simulate`
    /// sets one, so a long QA run or soak does not grow with the fake's own history (each record holds a table).
    public var recordLimit: Int? {
        get { lock.withLock { limit } }
        set { lock.withLock { limit = newValue; trimLog() } }
    }
    /// Number of `restoreSystemColorSettings()` calls.
    public var restoreCount: Int { lock.withLock { restores } }
    /// A write is blocked inside `stallNextWrite(until:)` right now.
    public var isWriteStalled: Bool { lock.withLock { stalled } }

    // MARK: GammaPort

    /// The base's length; 0 for a display without a table or an unknown one.
    public func capacity(of display: CGDirectDisplayID) -> Int { lock.withLock { displays[display]?.base?.count ?? 0 } }

    /// The live table (clamped at 1.0 while `clampsReadBack`).
    public func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        try lock.withLock {
            guard let entry = displays[display] else { throw GammaError.displayGone }
            guard let table = entry.table else { throw GammaError.noTable }
            return clamping ? Self.clamped(table) : table
        }
    }

    /// The display's base resampled to `count`; identity for an unknown display or one without a table.
    public func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        let base = lock.withLock { displays[display]?.base }
        guard let base else { return .identity(count: count) }
        return Self.resampled(base, count: count)
    }

    /// Records and applies `table` (after a stall, if one is armed). Fails with `failNextWrite(with:)`'s error once.
    public func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {
        let gate: DispatchSemaphore? = lock.withLock {
            defer { stall = nil }
            if stall != nil { stalled = true }
            return stall
        }
        if let gate {
            gate.wait()                                 // a WindowServer call that does not return yet
            lock.withLock { stalled = false }
        }
        try lock.withLock {
            if let error = failure { failure = nil; throw error }
            guard var entry = displays[display] else { throw GammaError.displayGone }
            guard entry.base != nil else { throw GammaError.noTable }
            entry.table = table
            if !ignoring { entry.screen = table }
            displays[display] = entry
            log.append(Write(display: display, table: table, time: time.now, isForeign: false))
            trimLog()
            successfulWrites += 1
            wroteATable = true
        }
    }

    /// Every display back to its base, or to all zeros while `restoreWritesZeros`; a no-op unless this process wrote a
    /// table first (as the real global restore).
    public func restoreSystemColorSettings() {
        lock.withLock {
            restores += 1
            guard wroteATable else { return }
            for (id, entry) in displays {
                guard let base = entry.base else { continue }
                let restored = zeroRestore ? Self.zeros(count: base.count) : base
                displays[id]?.table = restored
                displays[id]?.screen = restored
            }
        }
    }

    /// Successful `write(_:to:)` calls since the port was made.
    public var writeCount: Int { lock.withLock { successfulWrites } }

    // MARK: Simulations

    /// WindowServer reverts a dead process's writes: every display back to its base.
    public func simulateProcessDeath() { resetEveryDisplayToBase() }
    /// Any table writer's death resets every display to its base (§4.8).
    public func simulateOtherWriterDeath() { resetEveryDisplayToBase() }
    /// Another app writes `table` (not counted in `writeCount`).
    public func foreignWrite(_ table: GammaTable, to display: CGDirectDisplayID) {
        lock.withLock {
            guard displays[display] != nil else { return }
            displays[display]?.table = table
            displays[display]?.screen = table
            log.append(Write(display: display, table: table, time: time.now, isForeign: true))
            trimLog()
        }
    }

    /// Drops the oldest records once there are twice `limit` (amortized; called under the lock).
    private func trimLog() {
        guard let limit, log.count > 2 * max(limit, 1) else { return }
        log.removeFirst(log.count - limit)
    }
    /// A profile, preset or HDR change: the display gets a new base, which macOS applies to the live table now, or
    /// later (`appliesNow: false`, then `resetToBase(_:)`: the event can arrive before WindowServer's new table, §4.8).
    public func changeBase(_ base: GammaTable, for display: CGDirectDisplayID, appliesNow: Bool = true) {
        lock.withLock {
            guard displays[display] != nil else { return }
            displays[display]?.base = base
            if appliesNow {
                displays[display]?.table = base
                displays[display]?.screen = base
            }
        }
    }
    /// The display's live table back to its base (a system reset of one display).
    public func resetToBase(_ display: CGDirectDisplayID) {
        lock.withLock {
            guard let base = displays[display]?.base else { return }
            displays[display]?.table = base
            displays[display]?.screen = base
        }
    }
    /// The next `write(_:to:)` blocks until `release` is signalled (a stuck WindowServer call, §4.6).
    public func stallNextWrite(until release: DispatchSemaphore) { lock.withLock { stall = release } }
    /// The next `write(_:to:)` throws `error` (and writes nothing).
    public func failNextWrite(with error: GammaError) { lock.withLock { failure = error } }

    private func resetEveryDisplayToBase() {
        lock.withLock {
            for (id, entry) in displays {
                displays[id]?.table = entry.base
                displays[id]?.screen = entry.base
            }
        }
    }

    // MARK: Table helpers

    private static func clamped(_ table: GammaTable) -> GammaTable {
        GammaTable(red: table.red.map { min($0, 1) }, green: table.green.map { min($0, 1) },
                   blue: table.blue.map { min($0, 1) })
    }

    private static func zeros(count: Int) -> GammaTable {
        let zero = [Float](repeating: 0, count: count)
        return GammaTable(red: zero, green: zero, blue: zero)
    }

    /// Linear resampling of every channel to `count` samples.
    static func resampled(_ table: GammaTable, count: Int) -> GammaTable {
        guard count > 0 else { return GammaTable(red: [], green: [], blue: []) }
        guard table.count != count, table.count > 1 else {
            return table.count == count ? table : .identity(count: count)
        }
        func channel(_ samples: [Float]) -> [Float] {
            (0..<count).map { i in
                let x = Double(i) / Double(max(count - 1, 1)) * Double(samples.count - 1)
                let lower = Int(x.rounded(.down)), upper = min(lower + 1, samples.count - 1)
                let t = Float(x - Double(lower))
                return samples[lower] + (samples[upper] - samples[lower]) * t
            }
        }
        return GammaTable(red: channel(table.red), green: channel(table.green), blue: channel(table.blue))
    }
}
