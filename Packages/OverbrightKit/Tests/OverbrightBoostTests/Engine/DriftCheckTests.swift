// OverbrightBoostTests/Engine/DriftCheckTests.swift — the drift check (ARCHITECTURE.md §4.8): sampling where ×F and ×1
// are furthest apart, the separation rule, the evaluation order, factors 1.02–1.06 and dims 0.95–0.99 under both
// read-back models and with a calibrated base; and in the engine: resets reapply and count, the repair budget, the
// adoption window and budget, attribution, another writer's death.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct DriftCheckTests {
    private static let identity = GammaTable.identity(count: 1024)
    /// A calibrated (per-channel) base like a colorimeter profile's `vcgt`.
    private static let calibrated: GammaTable = {
        func curve(_ scale: Double, _ exponent: Double) -> [Float] {
            (0..<1024).map { Float(scale * pow(Double($0) / 1023, exponent)) }
        }
        return GammaTable(red: curve(0.985, 1.02), green: curve(1, 0.99), blue: curve(0.96, 0.98))
    }()
    /// Another profile base (a white-point change: every channel its own scale, not a uniform multiple).
    private static let otherBase: GammaTable = {
        func channel(_ scale: Double) -> [Float] { (0..<1024).map { Float(scale * Double($0) / 1023) } }
        return GammaTable(red: channel(0.92), green: channel(0.95), blue: channel(0.91))
    }()

    private static func clamped(_ table: GammaTable) -> GammaTable {
        GammaTable(red: table.red.map { min($0, 1) }, green: table.green.map { min($0, 1) },
                   blue: table.blue.map { min($0, 1) })
    }

    @Test func sampleIndexIsTheHighestEntryBelowTheCeiling() throws {
        let index = try #require(DriftCheck.sampleIndex(baseline: Self.identity, factor: 1.05))
        #expect(Double(Self.identity.green[index]) * 1.05 <= 0.98)
        #expect(Double(Self.identity.green[index + 1]) * 1.05 > 0.98)
        #expect(DriftCheck.sampleIndex(baseline: Self.identity, factor: 0.97) == 1023)
    }

    @Test(arguments: [1.03, 1.04, 1.05, 1.06])
    func boostFactorsClassifyUnderBothReadBackModels(factor: Double) {
        for base in [Self.identity, Self.calibrated] {
            for clamps in [false, true] {
                let read: (GammaTable) -> GammaTable = { clamps ? Self.clamped($0) : $0 }
                let written = base.scaled(by: factor)
                #expect(DriftCheck.evaluate(read: read(written), baseline: base, factor: factor, profileBase: base) == .fine)
                #expect(DriftCheck.evaluate(read: read(base), baseline: base, factor: factor, profileBase: base) == .reset)
                #expect(DriftCheck.evaluate(read: read(Self.otherBase), baseline: base, factor: factor,
                                            profileBase: Self.otherBase) == .adoptionCandidate)
                let foreign = GammaTable(red: base.red.map { $0 * 0.8 }, green: base.green, blue: base.blue)
                #expect(DriftCheck.evaluate(read: read(foreign), baseline: base, factor: factor, profileBase: base) == .foreign)
            }
        }
    }

    @Test func factorTwoHundredthsIsIndistinguishable() {
        let written = Self.identity.scaled(by: 1.02)
        #expect(DriftCheck.evaluate(read: Self.identity, baseline: Self.identity, factor: 1.02,
                                    profileBase: Self.identity) == .indistinguishable)
        #expect(DriftCheck.evaluate(read: written, baseline: Self.identity, factor: 1.02,
                                    profileBase: Self.identity) == .indistinguishable)
    }

    @Test(arguments: [0.95, 0.96, 0.97, 0.98])
    func dimFactorsClassify(factor: Double) {
        for base in [Self.identity, Self.calibrated] {
            #expect(DriftCheck.evaluate(read: base.scaled(by: factor), baseline: base, factor: factor,
                                        profileBase: base) == .fine)
            #expect(DriftCheck.evaluate(read: base, baseline: base, factor: factor, profileBase: base) == .reset)
        }
    }

    @Test func dimNinetyNineHundredthsIsIndistinguishable() {
        #expect(DriftCheck.evaluate(read: Self.identity, baseline: Self.identity, factor: 0.99,
                                    profileBase: Self.identity) == .indistinguishable)
    }

    // MARK: In the engine

    /// A reset is reapplied with a ramp (≥ 6 writes) after 250 ms and journalled; three in 6 s trip the display.
    @Test func resetsAreRepairedUntilTheBudget() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.gamma.resetToBase(1)
        await h.advance(.milliseconds(2_100))
        #expect(h.codes.contains("watchdog.reset"))
        let before = h.writes().count
        await h.advance(.milliseconds(700))
        #expect(h.writes().count - before >= EngineTiming.minimumRampSteps)
        #expect(h.codes.contains("drift.reapplied"))
        h.gamma.resetToBase(1)
        await h.advance(.seconds(2))
        h.gamma.resetToBase(1)
        let tripped = await h.advance(until: { h.phase() == .failed(.repairBudgetExceeded) }, limit: .seconds(3))
        #expect(tripped)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
    }

    /// Another table writer dies: every display is reset; the check 50 ms after `appTerminated` reapplies.
    @Test func anotherWritersDeathIsRepairedAt50Milliseconds() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.milliseconds(500))
        h.gamma.simulateOtherWriterDeath()
        h.signals.emit(.appTerminated(bundleID: "com.example.writer", processID: 77))
        await h.advance(.milliseconds(60))
        #expect(h.codes.contains("watchdog.reset"))
        await h.advance(.milliseconds(600))
        #expect(abs((h.liveFactor() ?? 0) - FactorMath.tableFactor(forLightGain: pow(ReferenceReducer.defaultTop, 0.5),
                                                                    domain: .encoded)) < 1e-4)
    }

    /// A base change the drift check sees right after a ColorSync event is adopted after two identical reads.
    @Test func explainedAdoptionAdoptsTheNewBase() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.milliseconds(1_000))                             // the drift tick is 1 s away
        h.gamma.changeBase(Self.otherBase, for: 1)
        h.controller()?.lastBaseEventAt = h.time.now                     // the event, as Signals would deliver it
        await h.advance(.milliseconds(1_500))
        #expect(h.controller()?.baseline == Self.otherBase)
        #expect(h.codes.contains("baseline.adopted"))
        await h.advance(.milliseconds(500))
        let table = try #require(h.table())
        #expect(table.matches(Self.otherBase.scaled(by: h.controller()?.appliedFactor ?? 0), tolerance: 1e-5))
    }

    /// Unexplained base changes count as repairs and reversals; more than two in 60 s trip the display (attributed
    /// when the conflict probe names an app).
    @Test func unexplainedAdoptionsTrip() async throws {
        let h = EngineHarness()
        let app = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: "com.example.warm", processID: 9,
                                 displayName: "Warm")
        h.conflicts.driftAttribution = app
        await h.start()
        #expect(await h.boost())
        var tripped = false
        for _ in 0..<6 where !tripped {
            h.gamma.foreignWrite(Self.otherBase, to: 1)
            h.gamma.changeBase(Self.otherBase, for: 1, appliesNow: false)
            await h.advance(.milliseconds(2_100))
            h.gamma.changeBase(Self.identity, for: 1, appliesNow: false)
            await h.advance(.milliseconds(900))
            tripped = h.phase()?.isFailed ?? false
        }
        #expect(tripped)
        #expect(h.codes.contains("adoption.unexplained"))
        #expect(h.controller()?.baseline == Self.identity)
    }

    /// A conditional (S3) writer is tripped at its first attributed drift.
    @Test func conditionalWriterTripsAtTheFirstDrift() async throws {
        let h = EngineHarness()
        let app = ConflictingApp(entryID: "s3", severity: .conditional, bundleID: "com.example.cond", processID: 5,
                                 displayName: "Cond")
        h.conflicts.driftAttribution = app
        await h.start()
        #expect(await h.boost())
        h.gamma.foreignWrite(GammaTable(red: Self.identity.red.map { $0 * 0.7 }, green: Self.identity.green,
                                        blue: Self.identity.blue), to: 1)
        await h.advance(.milliseconds(2_100))
        #expect(h.phase() == .failed(.attributedDrift(app)))
        #expect(h.conflicts.attributionRequests >= 1)
        #expect(h.everyTableAtBase)
    }

    /// A drift on a dimmed display is repaired too.
    @Test func dimmedDisplayIsRepaired() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.3), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
        h.gamma.resetToBase(1)
        await h.advance(.milliseconds(2_700))
        #expect(h.codes.contains("watchdog.reset"))
        let factor = FactorMath.tableFactor(forLightGain: LevelMapping.dimLight(for: LevelPosition(-0.3)), domain: .encoded)
        #expect(abs((h.liveFactor() ?? 0) - factor) < 1e-4)
    }
}
