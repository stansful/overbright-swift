// OverbrightBoostTests/Engine/InvariantTests.swift — the twelve invariants of ARCHITECTURE.md §4.5, each with at least
// one scenario against the fakes (the property versions run in EngineFuzzTests).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct InvariantTests {
    private let base = GammaTable.identity(count: 1024)

    private func boosted(_ h: EngineHarness = EngineHarness()) async -> EngineHarness {
        await h.start()
        let boosted = await h.boost()
        #expect(boosted)
        return h
    }

    // MARK: 1 Interlock

    /// Every write above the base is backed by a fresh reading of the same display with `G ≤ 0.97 × H`, through
    /// raises, headroom drops and recoveries.
    @Test func interlockBacksEveryWrite() async throws {
        let h = EngineHarness(reducer: ReferenceReducer(top: 2.587))
        h.setPreferences { $0.capMode = .peak }
        await h.start()
        #expect(await h.boost())
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(500))
        h.scripted.setGrant(1.5, for: h.builtIn, over: .seconds(2))
        await h.advance(.seconds(3))
        h.scripted.setGrant(1600.0 / 600, for: h.builtIn, over: .seconds(1))
        await h.advance(.seconds(6))
        let breaches = h.interlockViolations()
        #expect(breaches.isEmpty, "\(breaches.prefix(5))")
        #expect(h.writes().count > 40)
    }

    // MARK: 2 Order

    /// Un-scale before removing a trigger: off, Back to Standard, shield + linger, occlusion, a window move and a
    /// trip all remove triggers only with the table at (or below) its base.
    @Test func unscaleBeforeEveryRemoval() async throws {
        let h = await boosted()
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(await h.boost())
        h.engine.returnToStandard(source: .menu)
        await h.advance(.seconds(1))
        #expect(await h.boost())
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        await h.advance(.seconds(11))
        h.signals.snapshot.isScreenLocked = false
        h.signals.emit(.unlocked)
        #expect(await h.boost())
        h.triggers.moveWindows(on: h.builtIn, toScreen: 42)
        h.signals.emit(.displaysReconfigured)
        #expect(await h.boost())
        for _ in 0..<5 where h.phase() != .failed(.repairBudgetExceeded) {
            h.gamma.resetToBase(1)                                        // a writer keeps resetting the display
            await h.advance(.milliseconds(2_600))
        }
        #expect(h.phase() == .failed(.repairBudgetExceeded))
        #expect(h.checkedTriggers.events.filter { $0.hasPrefix("remove:") }.count >= 5, "\(h.checkedTriggers.events)")
        #expect(h.orderViolations.isEmpty)
    }

    // MARK: 3 Single writer

    /// What reaches the port is always the baseline or a plain multiple of it (the writer's multiply), and a
    /// refused write reaches nothing. The source scan `onlyTableWriterAndRescueWrite` (Core lint) keeps every other
    /// caller away from `GammaPort.write`.
    @Test func everyWriteIsTheWritersMultiply() async throws {
        let h = await boosted()
        h.engine.setLevel(LevelPosition(-0.4), for: h.builtIn, source: .panel)
        await h.advance(.seconds(1))
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        #expect(await h.boost())
        #expect(h.writes().count > 30)
        for write in h.writes() {
            // One factor for every entry of every channel (where the base carries a ratio).
            let ratios = zip(write.table.channels, base.channels).flatMap { table, reference in
                zip(table, reference).filter { $1 >= 0.05 }.map { Double($0) / Double($1) }
            }
            let spread = (ratios.max() ?? 0) - (ratios.min() ?? 0)
            #expect(spread < 1e-5)
        }
    }

    // MARK: 4 Zero work while off

    /// Off and nothing dimmed: no trigger or overlay, no task, no sleeper, no polling, boost-only sources stopped.
    @Test func offMeansNoTasksNoWindows() async throws {
        let h = EngineHarness(fixture: .russianNames)
        await h.start()
        #expect(await h.boost(h.builtIn))
        h.engine.setLevel(LevelPosition(-0.5), for: DisplayFixture.Keys.mpg322ux, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.engine.activeTaskCount > 0)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.triggers.openWindowCount == 0)
        #expect(h.engine.activeTaskCount == 0)
        #expect(h.time.sleeperCount == 0)
        #expect(h.signals.boostActiveCalls.last == false)
        #expect(h.engine.settings[EngineRecords.boostMarker] == nil)
        let reads = h.scripted.readCount
        await h.advance(.seconds(60), step: .milliseconds(500))
        #expect(h.scripted.readCount == reads)
        #expect(h.everyTableAtBase)
    }

    /// Off, the only tasks Boost may hold are one-shot trailing slots that end by themselves (as built, energy E2, E3,
    /// E6): a screen-parameters notification's coalesced reduction (≤ 100 ms) and the publish of a reading it moved
    /// (≤ 250 ms), and, while the self-test or a calibration holds the master off, the deferred level write (500 ms).
    /// Once they fired nothing runs, and nothing comes back without a new event or request.
    @Test func offHoldsOnlyOneShotTrailingSlots() async throws {
        let h = EngineHarness()
        await h.start()
        await h.advance(.seconds(1))
        #expect(h.engine.activeTaskCount == 0 && h.time.sleeperCount == 0)
        let trailing: Set<String> = ["screenParameters", "minorPublish", "levelPersist"]
        h.scripted.setOverride(2.6, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        #expect(h.engine.activeTaskNames.contains("screenParameters"))
        #expect(Set(h.engine.activeTaskNames).isSubset(of: trailing), "\(h.engine.activeTaskNames)")
        await h.advance(EngineTiming.screenParametersReduceInterval + EngineTiming.minorPublishInterval)
        #expect(h.engine.activeTaskNames == [] && h.time.sleeperCount == 0)
        h.engine.holdForInstrument()
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
        #expect(!h.engine.isMasterOn)                                     // turning on was refused
        #expect(h.engine.activeTaskNames.contains("levelPersist"))
        #expect(Set(h.engine.activeTaskNames).isSubset(of: trailing), "\(h.engine.activeTaskNames)")
        await h.advance(EngineTiming.levelPersistDelay + EngineTiming.minorPublishInterval)
        #expect(h.engine.activeTaskNames == [] && h.time.sleeperCount == 0)
        let reads = h.scripted.readCount
        await h.advance(.seconds(60), step: .milliseconds(500))
        #expect(h.engine.activeTaskCount == 0 && h.time.sleeperCount == 0)
        #expect(h.scripted.readCount == reads)
        #expect(h.triggers.openWindowCount == 0 && h.everyTableAtBase)
    }

    // MARK: 5 Baselines against the profile base

    /// A scaled residue (also when read-back clamps) is never captured; a per-channel calibration curve is, and is
    /// multiplied; a uniform multiple of the previous baseline is never adopted.
    @Test func baselinesAreJudgedAgainstTheProfileBase() async throws {
        for clamps in [false, true] {
            let h = EngineHarness()
            h.gamma.clampsReadBack = clamps
            h.gamma.addDisplay(1, base: base, table: base.scaled(by: 1.2))
            await h.start()
            h.engine.setOn(true, source: .panel)
            await h.settle()
            #expect(h.phase() == .failed(.foreignTableAtLaunch))
            #expect(h.gamma.writeCount == 0 && h.controller()?.baseline == nil)
        }
        let loader = GammaTable(red: base.red.map { $0 * 0.97 }, green: base.green, blue: base.blue.map { $0 * 0.93 })
        let h = EngineHarness()
        h.gamma.addDisplay(1, base: base, table: loader)
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.baseline == loader && h.codes.contains("baseline.foreign"))
        let factor = try #require(h.controller()?.appliedFactor)
        #expect(h.table()?.matches(loader.scaled(by: factor), tolerance: 1e-6) == true)
        for multiple in [loader.scaled(by: 1.1), loader.scaled(by: 0.8)] {          // another booster or dimmer on top
            let rejected: Bool = if case .reject = BaselineRules.capture(multiple, expectedBase: base,
                                                                         previous: loader) { true } else { false }
            #expect(rejected)
        }
    }

    // MARK: 6 Shielded means neutral

    /// Every shield event leaves every scaled or dimmed display at its baseline by the time `emit` returns.
    @Test(arguments: [SystemEvent.locked, .screensaverStarted, .willSleep, .screensDidSleep, .sessionResigned])
    func shieldIsNeutralWhenEmitReturns(event: SystemEvent) async throws {
        let h = EngineHarness(fixture: .russianNames)
        await h.start()
        #expect(await h.boost(h.builtIn))
        h.engine.setLevel(LevelPosition(-0.5), for: DisplayFixture.Keys.mpg322ux, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(!h.everyTableAtBase)
        h.signals.emit(event)
        #expect(h.everyTableAtBase)
        #expect(h.engine.ledger.entries().isEmpty)
    }

    // MARK: 7 Generations and epochs

    /// Turning off while the gate polls: the stale gate never ramps, nothing scaled is ever written.
    @Test func staleGenerationsNeverWrite() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(1_500))
        #expect(h.phase() == .gating(rung: 5))
        h.engine.setOn(false, source: .panel)
        h.engine.setOn(true, source: .panel)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(10))
        #expect(h.writes().isEmpty)
        #expect(h.phase() == .idle && h.liveTriggers().isEmpty && h.engine.activeTaskCount == 0)
    }

    /// The hang watchdog fires while a ramp step is stuck inside WindowServer: the in-flight write lands first, the
    /// watchdog's baselines after it, every queued scaled write is refused by the stale epoch, and nothing scaled
    /// lands until the engine has re-gated with a fresh reading (§4.6).
    @Test func hangEpochBlocksQueuedWrites() async throws {
        let h = await boosted()
        await h.advance(.seconds(1))
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(50), step: .milliseconds(1))
        let release = DispatchSemaphore(value: 0)
        let watchdogDone = DispatchSemaphore(value: 0)
        let gamma = h.gamma, ledger = h.engine.ledger, writer = h.engine.writer
        gamma.stallNextWrite(until: release)
        DispatchQueue.global(qos: .userInitiated).async { @Sendable in
            while !gamma.isWriteStalled { usleep(200) }
            DispatchQueue.global(qos: .utility).async { @Sendable in
                ledger.withLock { state in                                // what HangWatchdog does
                    state.hangEpoch += 1
                    writer.writeBaselines(fromLedger: state)
                    state.entries = [:]
                }
                watchdogDone.signal()
            }
            usleep(20_000)                                                // the watchdog now waits for the lock
            release.signal()
        }
        await h.time.advance(by: .milliseconds(17), yields: 50)           // the next ramp step stalls in the write
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async { @Sendable in
                watchdogDone.wait()
                continuation.resume()
            }
        }
        let watchdogAt = h.time.now
        #expect(h.everyTableAtBase)                                       // the baselines landed after the stuck write
        let afterWatchdog = h.gamma.writes.count
        await h.advance(.milliseconds(1_000))
        let soon = h.gamma.writes.dropFirst(afterWatchdog).filter { $0.table != base }
        #expect(soon.isEmpty)
        #expect(h.codes.contains("interlock.refusedStaleEpoch") && h.codes.contains("hang.restored"))
        #expect(await h.boost())
        let firstScaled = try #require(h.gamma.writes.dropFirst(afterWatchdog).first { $0.table != base })
        #expect(firstScaled.time - watchdogAt >= EngineTiming.stabilityWindow)
        #expect(h.controller()?.epochStamp == 1)
    }

    // MARK: 8 Flicker safety

    /// A fast user drag back and forth: opposing ramps never start closer than 500 ms apart.
    @Test func opposingTransitionsAreFiveHundredMillisecondsApart() async throws {
        let h = await boosted()
        await h.advance(.seconds(1))
        let start = h.writes().count
        for index in 0..<12 {
            let level = index.isMultiple(of: 2) ? LevelPreset.max.position : LevelPreset.indoor.position
            h.engine.setLevel(level, for: h.builtIn, source: .panel)
            await h.advance(.milliseconds(350), step: .milliseconds(5))
        }
        await h.advance(.seconds(1))
        let writes = Array(h.writes().dropFirst(start))
        var lastDirection: Bool?
        var reversals: [MonotonicInstant] = []
        for (previous, next) in zip(writes, writes.dropFirst()) {
            guard let a = EngineHarness.factor(of: previous.table, over: base),
                  let b = EngineHarness.factor(of: next.table, over: base), abs(a - b) > 1e-9 else { continue }
            let up = b > a
            if let lastDirection, lastDirection != up { reversals.append(next.time) }
            lastDirection = up
        }
        #expect(reversals.count >= 2)
        for (a, b) in zip(reversals, reversals.dropFirst()) { #expect(b - a >= .milliseconds(499)) }
        #expect(h.phase() != .failed(.oscillation))                       // user drags never trip the detector
    }

    // MARK: 9 Ledger before write

    /// While boosted the ledger holds the captured baseline; the baseline write that ends it clears the entry.
    @Test func ledgerFollowsTheScaledState() async throws {
        let h = await boosted()
        #expect(h.engine.ledger.entries().map(\.baseline) == [base])
        #expect(h.engine.ledger.entries().map(\.display.key) == [h.builtIn])
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.engine.ledger.entries().isEmpty)
    }

    // MARK: 10 No name logic

    /// The same built-in under a Russian name behaves byte for byte the same (D8).
    @Test func namesNeverChangeBehaviour() async throws {
        func run(_ fixture: DisplayFixture) async -> [GammaTable] {
            let h = EngineHarness(fixture: fixture)
            await h.start()
            _ = await h.boost(h.builtIn)
            h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
            await h.advance(.seconds(2))
            return h.writes(h.builtIn).map(\.table)
        }
        let english = await run(.builtinXDRLidOpen)
        let russian = await run(.russianNames)
        #expect(!english.isEmpty && english == russian)
    }

    // MARK: 11 One engine, on the console

    /// Started off the console: nothing is written and no trigger opens until the session becomes active.
    @Test func noWriteOffTheConsole() async throws {
        let h = EngineHarness()
        h.signals.snapshot.isSessionActive = false
        await h.start()
        h.engine.setOn(true, source: .panel)
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.seconds(5))
        #expect(h.gamma.writeCount == 0 && h.triggers.made.isEmpty)
        h.signals.snapshot.isSessionActive = true
        h.signals.emit(.sessionBecameActive)
        await h.advance(.seconds(1))
        #expect(h.phase() == .dimmed)
    }

    // MARK: 12 Every reapply ramps

    /// After a reset, another app's termination and a base adoption, the reapply is a ramp of ≥ 6 writes within
    /// 300 ms (after the 250 ms reset delay), journalled with its cause.
    @Test func everyReapplyRamps() async throws {
        let h = await boosted()
        await h.advance(.seconds(1))
        for disturb in 0..<3 {
            let before = h.writes().count
            let reapplied = h.codes.filter { $0 == "drift.reapplied" }.count
            switch disturb {
            case 0:
                h.gamma.resetToBase(1)
                await h.advance(.milliseconds(2_000))
            case 1:
                h.gamma.simulateOtherWriterDeath()
                h.signals.emit(.appTerminated(bundleID: nil, processID: 31))
            default:
                h.gamma.changeBase(GammaTable(red: base.red.map { $0 * 0.95 }, green: base.green,
                                              blue: base.blue.map { $0 * 0.9 }), for: 1)
                h.signals.emit(.colorProfileChanged)
            }
            await h.advance(.milliseconds(900))
            let ramp = Array(h.writes().dropFirst(before))
            #expect(ramp.count >= EngineTiming.minimumRampSteps, "disturbance \(disturb)")
            if let first = ramp.first, let last = ramp.last {
                #expect(last.time - first.time <= EngineTiming.rampDuration, "disturbance \(disturb)")
            }
            #expect(h.codes.filter { $0 == "drift.reapplied" }.count == reapplied + 1, "disturbance \(disturb)")
            await h.advance(.seconds(7))                                  // let the repair budget's window pass
        }
    }
}
