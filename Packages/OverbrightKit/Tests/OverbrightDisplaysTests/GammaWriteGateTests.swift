// OverbrightDisplaysTests/GammaWriteGateTests.swift — the write machinery of the real `CoreGraphicsGamma`
// (ARCHITECTURE.md §3.6, §8.1 rule 4, §10.4 "write counter; thread-safe for the watchdog and signal queues"), with the
// CoreGraphics call replaced by a recording closure: malformed tables never reach CoreGraphics, failures are not
// counted, and writes and the restore from several threads never overlap and are all counted.
import CoreGraphics
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

/// Counts calls and the largest number of calls in flight at once.
private nonisolated final class Overlap: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = 0
    private(set) var maximum = 0
    private(set) var calls = 0
    func enter() { lock.withLock { inFlight += 1; calls += 1; maximum = max(maximum, inFlight) } }
    func leave() { lock.withLock { inFlight -= 1 } }
    /// A short stretch of work while "inside" CoreGraphics.
    func work() { for _ in 0..<2_000 { _ = lock.withLock { inFlight } } }
}

@Suite struct GammaWriteGateTests {
    private let identity = GammaTable.identity(count: 1024)

    @Test func malformedTablesNeverReachCoreGraphics() {
        let gate = GammaWriteGate()
        let illegal = GammaError.coreGraphics(code: CGError.illegalArgument.rawValue)
        let tooShort = GammaTable(red: [0], green: [0], blue: [0])
        let ragged = GammaTable(red: identity.red, green: Array(identity.green.dropLast()), blue: identity.blue)
        var nan = identity
        nan.blue[10] = .nan
        var negative = identity
        negative.red[0] = -0.01
        for table in [tooShort, ragged, nan, negative, GammaTable.identity(count: 2048)] {
            var called = false
            #expect(throws: illegal) {
                try gate.perform(table, online: true, capacity: 1024) { _ in called = true; return .success }
            }
            #expect(!called)
        }
        #expect(gate.successfulWrites == 0)
        // Entries above 1 are the boost: allowed.
        var boosted = identity
        boosted.red[1023] = 1.6
        #expect(GammaWriteGate.isWritable(boosted, capacity: 1024))
        #expect(GammaWriteGate.isWritable(.identity(count: 256), capacity: 1024))
    }

    @Test func goneOrTablelessDisplaysThrowBeforeCoreGraphics() {
        let gate = GammaWriteGate()
        var called = false
        #expect(throws: GammaError.displayGone) {
            try gate.perform(identity, online: false, capacity: 1024) { _ in called = true; return .success }
        }
        #expect(throws: GammaError.noTable) {
            try gate.perform(identity, online: true, capacity: 0) { _ in called = true; return .success }
        }
        #expect(!called && gate.successfulWrites == 0)
    }

    @Test func onlyAcceptedWritesAreCounted() throws {
        let gate = GammaWriteGate()
        #expect(throws: GammaError.coreGraphics(code: CGError.failure.rawValue)) {
            try gate.perform(identity, online: true, capacity: 1024) { _ in .failure }
        }
        #expect(gate.successfulWrites == 0)
        var received: GammaTable?
        try gate.perform(identity, online: true, capacity: 1024) { table in received = table; return .success }
        #expect(received == identity)                                     // as given, nothing rescaled
        #expect(gate.successfulWrites == 1)
    }

    @Test func writesAndRestoresFromSeveralThreadsNeverOverlap() {
        let gate = GammaWriteGate()
        let overlap = Overlap()
        let table = identity
        DispatchQueue.concurrentPerform(iterations: 400) { index in
            if index % 50 == 0 {
                gate.performRestore { overlap.enter(); overlap.work(); overlap.leave() }
            } else {
                try? gate.perform(table, online: true, capacity: 1024) { _ in
                    overlap.enter(); overlap.work(); overlap.leave()
                    return .success
                }
            }
        }
        #expect(overlap.calls == 400)
        #expect(overlap.maximum == 1)                                     // one WindowServer call at a time
        #expect(gate.successfulWrites == 392)                            // restores are not writes
    }
}
