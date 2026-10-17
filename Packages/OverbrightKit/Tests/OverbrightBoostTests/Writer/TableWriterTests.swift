// OverbrightBoostTests/Writer/TableWriterTests.swift — the interlock (ARCHITECTURE.md §4.5 invariants 1, 9, §4.6,
// §5.4): readings of the same display at most 150 ms old, the hang epoch under the ledger lock, `liveCap` clamps,
// baseline writes for no-op boosts and low headroom, dims without readings, the ledger before every scaled write,
// calibration factors and the watchdog's baseline path. Only FakeGammaPort is written.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@Suite struct TableWriterTests {
    private let facts = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private let base = GammaTable.identity(count: 1024)

    private func make() -> (TableWriter, FakeGammaPort, SafetyLedger, ManualTimeSource, RingBufferJournal) {
        let time = ManualTimeSource()
        let gamma = FakeGammaPort(fixture: .builtinXDRLidOpen, time: time)
        let ledger = SafetyLedger()
        let journal = RingBufferJournal()
        return (TableWriter(gamma: gamma, ledger: ledger, time: time, journal: journal), gamma, ledger, time, journal)
    }

    private func request(_ gain: Double, capMode: CapMode = .peak, taper: Bool = false) -> TableWriter.Request {
        TableWriter.Request(gain: gain, domain: .encoded, baseline: base, facts: facts, capMode: capMode, isOLED: false,
                            sdrWhite: nil, taper: taper, fullBrightnessHeadroom: 1600.0 / 600)
    }

    private func reading(_ h: Double, display: UInt32 = 1, at time: MonotonicInstant) -> HeadroomReading {
        HeadroomReading(display: display, current: h, potential: 16, reference: 0, time: time)
    }

    @Test func scaledWriteMultipliesTheBaselineAndMarksTheLedger() throws {
        let (writer, gamma, ledger, time, _) = make()
        let outcome = try writer.write(request(1.5), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        #expect(outcome.appliedGain == 1.5 && outcome.limit == nil)
        #expect(abs(outcome.factor - pow(1.5, 1 / 2.4)) < 1e-12)
        let table = try #require(gamma.table(of: 1))
        #expect(table.matches(base.scaled(by: outcome.factor), tolerance: 1e-7))
        #expect(table.maximum <= Float(outcome.factor) * base.maximum + 1e-6)   // never above F × max(B)
        #expect(ledger.entries().map(\.baseline) == [base])
    }

    @Test func foreignStaleOrMissingReadingsAreRefused() async throws {
        let (writer, gamma, _, time, journal) = make()
        #expect(throws: GammaError.writeRefused) {
            try writer.write(request(1.3), to: facts.ref, reading: reading(2.667, display: 2, at: time.now), epoch: 0)
        }
        #expect(throws: GammaError.writeRefused) {
            try writer.write(request(1.3), to: facts.ref, reading: nil, epoch: 0)
        }
        let old = reading(2.667, at: time.now)
        await time.advance(by: .milliseconds(151))
        #expect(throws: GammaError.writeRefused) {
            try writer.write(request(1.3), to: facts.ref, reading: old, epoch: 0)
        }
        let fresh = reading(2.667, at: time.now)
        await time.advance(by: .milliseconds(150))
        #expect(throws: Never.self) { try writer.write(request(1.3), to: facts.ref, reading: fresh, epoch: 0) }
        #expect(gamma.writeCount == 1)
        let codes = journal.snapshot().map(\.code)
        #expect(codes.contains("interlock.refusedForeignReading") && codes.contains("interlock.refusedStaleReading")
                && codes.contains("interlock.refusedNoReading"))
    }

    @Test func staleEpochIsRefusedButBaselinesAreNot() throws {
        let (writer, gamma, ledger, time, journal) = make()
        ledger.withLock { $0.hangEpoch = 1 }
        #expect(throws: GammaError.writeRefused) {
            try writer.write(request(1.3), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        }
        #expect(throws: GammaError.writeRefused) {
            try writer.write(request(0.5), to: facts.ref, reading: nil, epoch: 0)       // dims respect the epoch too
        }
        #expect(gamma.writeCount == 0)
        try writer.write(request(1), to: facts.ref, reading: nil, epoch: 0)             // the baseline always writes
        #expect(gamma.writeCount == 1 && gamma.table(of: 1) == base)
        #expect(journal.snapshot().map(\.code).contains("interlock.refusedStaleEpoch"))
    }

    @Test func liveCapClampsAndJournals() throws {
        let (writer, _, _, time, journal) = make()
        let outcome = try writer.write(request(2.5), to: facts.ref, reading: reading(2.0, at: time.now), epoch: 0)
        #expect(abs(outcome.appliedGain - 0.97 * 2.0) < 1e-12)
        #expect(outcome.limit == .headroom)
        #expect(journal.snapshot().map(\.code).contains("interlock.clamped"))
        let safe = try writer.write(request(1.667, capMode: .safe), to: facts.ref, reading: reading(2.0, at: time.now),
                                    epoch: 0)
        #expect(abs(safe.appliedGain - 1000 * 2.0 / 1600) < 1e-12 && safe.limit == .safeLimit)
    }

    @Test func noOpBoostsAndLowHeadroomWriteTheBaseline() throws {
        let (writer, gamma, ledger, time, _) = make()
        _ = try writer.write(request(1.5), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        let low = try writer.write(request(1.5), to: facts.ref, reading: reading(1.02, at: time.now), epoch: 0)
        #expect(low.appliedGain == 1 && low.factor == 1 && gamma.table(of: 1) == base)
        #expect(ledger.entries().isEmpty)                                             // unmarked after the baseline
        let tiny = try writer.write(request(1.003), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        #expect(tiny.appliedGain == 1 && gamma.table(of: 1) == base)
    }

    @Test func dimsNeedNoReading() throws {
        let (writer, gamma, ledger, _, _) = make()
        let outcome = try writer.write(request(0.25), to: facts.ref, reading: nil, epoch: 0)
        #expect(abs(outcome.factor - FactorMath.encodeSRGB(0.25)) < 1e-12)
        #expect(gamma.table(of: 1)?.matches(base.scaled(by: outcome.factor), tolerance: 1e-7) == true)
        #expect(ledger.entries().count == 1)
    }

    /// Invariant 9: the ledger records the display before the scaled write is issued, so a write that fails inside
    /// WindowServer still leaves the baseline for the watchdog.
    @Test func ledgerIsMarkedBeforeTheWrite() throws {
        let (writer, gamma, ledger, time, _) = make()
        gamma.failNextWrite(with: .coreGraphics(code: 1001))
        #expect(throws: GammaError.coreGraphics(code: 1001)) {
            try writer.write(request(1.3), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        }
        #expect(ledger.isMarked(facts.ref.key))
        #expect(ledger.withLock { writer.writeBaselines(fromLedger: $0) } == 1)
        #expect(gamma.table(of: 1) == base)
    }

    /// A scaled write the port refused before any WindowServer call (the display is not online, or has no table)
    /// changed nothing on screen: the ledger is left as it was, so a display never scaled holds no entry (the hang
    /// watchdog and the boost marker follow the ledger) and a scaled one keeps the baseline it was marked with.
    @Test func aWriteThatNeverReachedWindowServerLeavesTheLedgerAsItWas() throws {
        let (writer, gamma, ledger, time, _) = make()
        for error in [GammaError.displayGone, .noTable] {
            gamma.failNextWrite(with: error)
            #expect(throws: error) {
                try writer.write(request(1.3), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
            }
            #expect(!ledger.isMarked(facts.ref.key), "\(error)")
        }
        try writer.write(request(0.5), to: facts.ref, reading: nil, epoch: 0)
        var other = request(0.6)
        other.baseline = base.scaled(by: 0.9)
        gamma.failNextWrite(with: .displayGone)
        #expect(throws: GammaError.displayGone) { try writer.write(other, to: facts.ref, reading: nil, epoch: 0) }
        #expect(ledger.entries().map(\.baseline) == [base])                     // the entry of the dim on screen
        gamma.failNextWrite(with: .coreGraphics(code: 1001))                     // WindowServer may have taken it
        #expect(throws: GammaError.coreGraphics(code: 1001)) {
            try writer.write(other, to: facts.ref, reading: nil, epoch: 0)
        }
        #expect(ledger.entries().map(\.baseline) == [other.baseline])
    }

    /// The calibration path (§5.2): bounded by the session's `maxFactor` and the reading's calibration ceiling, never by
    /// the boost interlock's `0.97 × H`, which the sweep must pass to find where white clips (C-BOOST-5).
    @Test func calibrationFactorsAreBoundedByMaxAndTheCeiling() throws {
        let (writer, gamma, ledger, time, _) = make()
        let now = reading(2.667, at: time.now)
        try writer.writeCalibrationFactor(1.2, of: base, to: facts.ref, reading: now, maxFactor: 2, epoch: 0)
        #expect(gamma.table(of: 1)?.matches(base.scaled(by: 1.2), tolerance: 1e-7) == true)
        #expect(ledger.entries().map(\.baseline) == [base])                         // marked with the write
        #expect(throws: GammaError.writeRefused) {
            try writer.writeCalibrationFactor(2.1, of: base, to: facts.ref, reading: now, maxFactor: 2, epoch: 0)
        }
        let past = FactorMath.headroomMargin * 2.667 + 0.05                            // above 0.97 × H
        try writer.writeCalibrationFactor(past, of: base, to: facts.ref, reading: now, maxFactor: 3, epoch: 0)
        #expect(gamma.table(of: 1)?.matches(base.scaled(by: past), tolerance: 1e-6) == true)
        let ceiling = CalibrationMath.writeCeiling(headroom: 2.667)
        #expect(ceiling > CalibrationMath.sweepCap(headroom: 2.667))
        #expect(throws: GammaError.writeRefused) {                                     // no session goes past it
            try writer.writeCalibrationFactor(ceiling + 0.02, of: base, to: facts.ref, reading: now, maxFactor: 5,
                                              epoch: 0)
        }
        try writer.writeCalibrationFactor(1, of: base, to: facts.ref, reading: now, maxFactor: 2, epoch: 0)
        #expect(gamma.table(of: 1) == base && !ledger.isMarked(facts.ref.key))
    }

    /// A calibration factor needs a fresh reading of the same display and the current hang epoch, checked under the
    /// ledger lock like every scaled write: a sweep step queued behind a hang never re-scales a restored display
    /// (§4.5 invariant 1(b), §4.6; C-BOOST-8). Its un-scale is never refused.
    @Test func calibrationFactorsRespectTheReadingAndTheHangEpoch() async throws {
        let (writer, gamma, ledger, time, journal) = make()
        #expect(throws: GammaError.writeRefused) {                                     // another display's reading
            try writer.writeCalibrationFactor(1.2, of: base, to: facts.ref,
                                              reading: reading(2.667, display: 9, at: time.now), maxFactor: 2, epoch: 0)
        }
        let old = reading(2.667, at: time.now)
        await time.advance(by: .milliseconds(151))
        #expect(throws: GammaError.writeRefused) {                                     // older than 150 ms
            try writer.writeCalibrationFactor(1.2, of: base, to: facts.ref, reading: old, maxFactor: 2, epoch: 0)
        }
        try writer.writeCalibrationFactor(1.2, of: base, to: facts.ref, reading: reading(2.667, at: time.now),
                                          maxFactor: 2, epoch: 0)
        let restored = EmergencyRestore.run(writer: writer, ledger: ledger)             // the hang watchdog fired
        #expect(restored.displays == 1 && gamma.table(of: 1) == base)
        let writes = gamma.writeCount
        #expect(throws: GammaError.writeRefused) {
            try writer.writeCalibrationFactor(1.24, of: base, to: facts.ref, reading: reading(2.667, at: time.now),
                                              maxFactor: 2, epoch: 0)
        }
        #expect(gamma.writeCount == writes && gamma.table(of: 1) == base && !ledger.isMarked(facts.ref.key))
        #expect(journal.snapshot().map(\.code).contains("interlock.refusedStaleEpoch"))
        try writer.writeCalibrationFactor(1, of: base, to: facts.ref, reading: reading(2.667, at: time.now),
                                          maxFactor: 2, epoch: 0)
        try writer.writeCalibrationFactor(1.24, of: base, to: facts.ref, reading: reading(2.667, at: time.now),
                                          maxFactor: 2, epoch: restored.epoch)         // a new session's stamp
        #expect(gamma.table(of: 1)?.matches(base.scaled(by: 1.24), tolerance: 1e-6) == true)
    }

    @Test func watchdogPathWritesEveryLedgerBaseline() throws {
        let gamma = FakeGammaPort(fixture: .russianNames)
        let ledger = SafetyLedger()
        let time = ManualTimeSource()
        let writer = TableWriter(gamma: gamma, ledger: ledger, time: time, journal: RingBufferJournal())
        let displays = DisplayFixture.russianNames.displays.map(\.facts)
        for display in displays {
            _ = try writer.write(request(1.4), to: display.ref,
                                 reading: reading(2.667, display: display.ref.id, at: time.now), epoch: 0)
        }
        let written = ledger.withLock { state in
            state.hangEpoch += 1
            return writer.writeBaselines(fromLedger: state)
        }
        #expect(written == 2)
        #expect(displays.allSatisfy { gamma.table(of: $0.ref.id) == gamma.base(of: $0.ref.id) })
    }

    /// The writer is safe from any thread: the watchdog's queue writes baselines while the main path writes.
    @Test func baselinesFromABackgroundQueue() async throws {
        let (writer, gamma, ledger, time, _) = make()
        _ = try writer.write(request(1.5), to: facts.ref, reading: reading(2.667, at: time.now), epoch: 0)
        let written = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            DispatchQueue.global(qos: .utility).async { @Sendable in
                continuation.resume(returning: ledger.withLock { state in
                    state.hangEpoch += 1
                    return writer.writeBaselines(fromLedger: state)
                })
            }
        }
        #expect(written == 1 && gamma.table(of: 1) == base)
    }
}
