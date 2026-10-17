// OverbrightBoostTests/Engine/EngineFuzzTests.swift — the engine property test of ARCHITECTURE.md §9.1: across 10 000
// random event sequences (seeded, reproducible), every write above the base is backed by a reading of the same display
// at most 150 ms old with `G ≤ 0.97 × H`, no trigger is removed while its table is scaled, every sequence that ends
// with the master off leaves every table at its baseline with no window and no task, and at least 30 % of the
// sequences reach `boosted` (so the property is not vacuous). WindowServer refusing a write is one of the actions.
// A sequence does not depend on how loaded the machine is: the engine, its fakes and its tasks all run on the main
// actor, whose jobs run in the order they were queued, and time moves only with the manual clock (§9.1).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct EngineFuzzTests {
    /// 10 000 (§9.1); `OVERBRIGHT_FUZZ_SEQUENCES` narrows a local run.
    static let sequences = ProcessInfo.processInfo.environment["OVERBRIGHT_FUZZ_SEQUENCES"].flatMap { Int($0) } ?? 10_000

    /// What one sequence showed.
    struct Outcome {
        var breaches: [String] = []
        var reachedBoosted = false
    }

    @Test func randomSequencesKeepTheInvariants() async throws {
        // A fixed seed keeps CI reproducible; `OVERBRIGHT_FUZZ_SEED` explores other sequences locally.
        let master = ProcessInfo.processInfo.environment["OVERBRIGHT_FUZZ_SEED"].flatMap { UInt64($0) } ?? 0x0B21_E7F1
        var seeds = SeededGenerator(seed: master)
        var boosted = 0
        for _ in 0..<Self.sequences {
            let seed = seeds.next()
            let outcome = await run(seed: seed)
            if outcome.reachedBoosted { boosted += 1 }
            guard outcome.breaches.isEmpty else {
                Issue.record("seed \(seed): \(outcome.breaches.prefix(4))")
                return
            }
        }
        #expect(Double(boosted) >= 0.3 * Double(Self.sequences), "\(boosted) of \(Self.sequences) reached boosted")
    }

    /// The sequence that once left a table off its base and a task running after off, in a loaded parallel run of an
    /// earlier engine (WP14 leftovers); it replays the same way under any load.
    @Test func theSequenceThatFailedUnderLoadKeepsTheInvariants() async {
        let outcome = await run(seed: 13_576_627_718_912_785_137)
        #expect(outcome.breaches.isEmpty, "\(outcome.breaches)")
    }

    // MARK: One sequence

    private static let fixtures: [DisplayFixture] = [.builtinXDRLidOpen, .russianNames, .proDisplayXDR, .mpg322uxHDROn]
    /// Coarse time steps and few yields keep 10 000 sequences fast; every task still runs, only later.
    private static let step = Duration.milliseconds(100)
    private static let yields = 1

    /// One sequence over `decide` (the reference reducer by default).
    func run(seed: UInt64, decide: ((PolicyInput) -> PolicyDecision)? = nil) async -> Outcome {
        var random = SeededGenerator(seed: seed)
        let fixture = Self.fixtures[Int.random(in: 0..<Self.fixtures.count, using: &random)]
        let h = EngineHarness(fixture: fixture, decide: decide)
        if Bool.random(using: &random) { h.setPreferences { $0.capMode = .peak } }
        h.gamma.clampsReadBack = Bool.random(using: &random)
        let keys = h.directory.displays.map(\.ref.key)
        await h.start()
        var outcome = Outcome()
        if Int.random(in: 0..<10, using: &random) < 6 {                   // most sequences start by turning on
            h.engine.setOn(true, source: .panel)
            await h.advance(.milliseconds(Int.random(in: 3_000...5_000, using: &random)), step: Self.step,
                            yields: Self.yields)
            if keys.contains(where: { h.phase($0) == .boosted }) { outcome.reachedBoosted = true }
        }
        for _ in 0..<Int.random(in: 4...8, using: &random) {
            act(h, keys: keys, random: &random)
            await h.advance(.milliseconds(Int.random(in: 50...1_500, using: &random)), step: Self.step,
                            yields: Self.yields)
            if keys.contains(where: { h.phase($0) == .boosted }) { outcome.reachedBoosted = true }
        }
        // End off: shields lifted, master off, ramps finished.
        h.scripted.setOverride(nil)
        h.signals.snapshot.isScreenLocked = false
        h.signals.snapshot.isSystemSleeping = false
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(2), step: Self.step, yields: Self.yields)
        // One yield per coarse step keeps 10 000 sequences fast, but a task that hops more than once per step falls
        // behind (the same hops on every run, in queue order): let what is left finish with full yields before
        // anything counts as left behind.
        if h.engine.activeTaskCount != 0 {
            _ = await h.advance(until: { h.engine.activeTaskCount == 0 }, limit: .seconds(30))
        }
        outcome.breaches += h.interlockViolations()
        outcome.breaches += h.orderViolations
        if !h.everyTableAtBase { outcome.breaches.append("a table is not at its base after off") }
        if h.triggers.openWindowCount != 0 { outcome.breaches.append("\(h.triggers.openWindowCount) windows after off") }
        if h.engine.activeTaskCount != 0 {
            outcome.breaches.append("tasks after off: \(h.engine.activeTaskNames.joined(separator: ", "))")
        }
        h.engine.stopNow()
        return outcome
    }

    /// One random action: user requests, shields and wakes, headroom moves, resets by other writers, occlusion,
    /// reconfiguration, pauses and retries, and WindowServer refusing the next write.
    private func act(_ h: EngineHarness, keys: [DisplayKey], random: inout SeededGenerator) {
        let key = keys[Int.random(in: 0..<keys.count, using: &random)]
        switch Int.random(in: 0..<17, using: &random) {
        case 0, 1:
            h.engine.setOn(true, source: .panel)
        case 2:
            h.engine.setOn(false, source: .shortcut)
        case 3, 4:
            let level = LevelPosition(Double.random(in: -1...1, using: &random))
            h.engine.setLevel(level, for: Bool.random(using: &random) ? key : nil, source: .panel)
        case 5:
            h.engine.setDimLight(Double.random(in: 0.1...0.99, using: &random), for: key, source: .menu)
        case 6:
            h.engine.returnToStandard(source: .shortcut)
        case 7:
            let locked = !h.signals.snapshot.isScreenLocked
            h.signals.snapshot.isScreenLocked = locked
            h.scripted.setOverride(locked ? 1 : nil)
            h.signals.emit(locked ? .locked : .unlocked)
        case 8:
            let sleeping = !h.signals.snapshot.isSystemSleeping
            h.signals.snapshot.isSystemSleeping = sleeping
            h.signals.emit(sleeping ? .willSleep : .didWake)
        case 9:
            let grant = Double.random(in: 1...3.2, using: &random)
            h.scripted.setGrant(grant, for: key, over: .milliseconds(Int.random(in: 0...2_000, using: &random)))
            if Bool.random(using: &random) { h.signals.emit(.screenParametersChanged) }
        case 10:
            h.gamma.simulateOtherWriterDeath()
            h.signals.emit(.appTerminated(bundleID: nil, processID: 99))
        case 11:
            h.gamma.resetToBase(h.id(key))
        case 12:
            h.triggers.setOccluded(Bool.random(using: &random), on: key)
        case 13:
            h.signals.emit(.displaysReconfigured)
        case 14:
            if Bool.random(using: &random) {
                h.engine.pause(until: h.time.wallClock.addingTimeInterval(Double.random(in: 1...4, using: &random)),
                               source: .menu)
            } else {
                h.engine.resume(source: .menu)
            }
        case 15:
            h.engine.retry(key)
            h.engine.toggleDim(source: .menu)
        default:
            h.gamma.failNextWrite(with: .coreGraphics(code: 1000))
        }
    }
}
