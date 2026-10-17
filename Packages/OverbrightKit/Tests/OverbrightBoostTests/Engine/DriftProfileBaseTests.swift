// OverbrightBoostTests/Engine/DriftProfileBaseTests.swift — the drift tick asks for the profile base E″ only when its
// verdict consults it (ARCHITECTURE.md §4.8 step 1: E″ is recomputed fresh whenever it is consulted). On the real port
// E″ is a ColorSync profile copy, a `vcgt` parse and a resample, half of each tick. Counted with `CountingGammaPort`,
// never with timing; the verdicts themselves are pinned by DriftCheckTests.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct DriftProfileBaseTests {
    private static let identity = GammaTable.identity(count: 1024)
    /// Another profile base (a white-point change: every channel its own scale).
    private static let otherBase: GammaTable = {
        func channel(_ scale: Double) -> [Float] { (0..<1024).map { Float(scale * Double($0) / 1023) } }
        return GammaTable(red: channel(0.92), green: channel(0.95), blue: channel(0.91))
    }()

    private func harness() -> (EngineHarness, CountingGammaPort) {
        var port: CountingGammaPort?
        let h = EngineHarness(wrapGamma: { gamma, time in
            let counting = CountingGammaPort(gamma, time: time)
            port = counting
            return counting
        })
        return (h, port!)
    }

    // MARK: The pure check

    /// `.indistinguishable`, `.fine` and `.reset` never call the closure; `.adoptionCandidate` and `.foreign` call it
    /// once.
    @Test func evaluateCallsTheProfileBaseOnlyAfterFineAndReset() {
        let base = Self.identity
        let factor = 1.05
        func calls(_ read: GammaTable, factor: Double = 1.05, profile: GammaTable = Self.identity)
            -> (DriftCheck.Verdict, Int) {
            var count = 0
            let verdict = DriftCheck.evaluate(read: read, baseline: base, factor: factor, profileBase: {
                count += 1
                return profile
            })
            return (verdict, count)
        }
        #expect(calls(base.scaled(by: factor)) == (.fine, 0))
        #expect(calls(base) == (.reset, 0))
        #expect(calls(base.scaled(by: 1.02), factor: 1.02) == (.indistinguishable, 0))
        #expect(calls(Self.otherBase, profile: Self.otherBase) == (.adoptionCandidate, 1))
        let foreign = GammaTable(red: base.red.map { $0 * 0.8 }, green: base.green, blue: base.blue)
        #expect(calls(foreign) == (.foreign, 1))
    }

    // MARK: In the engine

    /// A steady boost: 30 drift ticks in 60 s read the table each time and never ask for the profile base.
    @Test func steadyTicksNeverComputeTheProfileBase() async throws {
        let (h, port) = harness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))
        port.resetCounts()
        await h.advance(.seconds(60), step: .milliseconds(100))
        #expect(port.reads.count >= 29)
        #expect(port.profileBaseCount == 0)
        #expect(h.phase() == .boosted)
    }

    /// A dim the drift check cannot tell from the baseline (×0.99-ish) and a reset: neither asks for it.
    @Test func indistinguishableAndResetTicksSkipIt() async throws {
        let (h, port) = harness()
        await h.start()
        h.engine.setDimLight(0.99, for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        await h.advance(.seconds(1))
        port.resetCounts()
        await h.advance(.seconds(20), step: .milliseconds(100))
        #expect(port.reads.count >= 9)
        #expect(port.profileBaseCount == 0)

        h.engine.setLevel(LevelPreset.brightRoom.position, for: h.builtIn, source: .panel)
        #expect(await h.boost())
        await h.advance(.seconds(4))
        port.resetCounts()
        h.gamma.resetToBase(1)                                            // the system put the baseline back
        #expect(await h.advance(until: { h.codes.contains("watchdog.reset") }, limit: .seconds(3)))
        await h.advance(.seconds(1))
        #expect(port.profileBaseCount == 0)
    }

    /// Another writer's table and an unexplained base change: E″ is computed once on that tick, fresh, and the
    /// adoption rules get that same value (the candidate is found and handled).
    @Test func foreignAndAdoptionTicksComputeItOnce() async throws {
        let (h, port) = harness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))
        port.resetCounts()
        h.gamma.foreignWrite(GammaTable(red: Self.identity.red.map { $0 * 0.7 }, green: Self.identity.green,
                                        blue: Self.identity.blue), to: 1)
        #expect(await h.advance(until: { h.codes.contains("watchdog.drift") }, limit: .seconds(3)))
        #expect(port.profileBaseCount == 1)

        await h.advance(.seconds(4))
        port.resetCounts()
        h.gamma.foreignWrite(Self.otherBase, to: 1)
        h.gamma.changeBase(Self.otherBase, for: 1, appliesNow: false)
        #expect(await h.advance(until: { h.codes.contains("adoption.unexplained") }, limit: .seconds(3)))
        #expect(port.profileBaseCount == 1)
    }
}
