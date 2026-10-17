// OverbrightBoostTests/Engine/LevelPersistenceTests.swift — level persistence is coalesced during drags (ARCHITECTURE.md
// §4.9): every step is stored at once for every reader (the reducer, the UI, the low-level rule, Signals), but the
// `defaults` write (a JSON encode of every display's preferences and a cfprefsd message) happens once,
// `levelPersistDelay` after the last step, and at once on stop, stopNow (after its baselines) and every turn-off; and a
// step costs one reduction, not two (the observed settings change it made is the one it reduced with). Counted with
// `CountingDefaults` and the reducer's inputs.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
import os
@testable import OverbrightBoost

@MainActor @Suite struct LevelPersistenceTests {
    private static let perDisplayKey = SettingsStore.keyPrefix + DisplaySettings.perDisplay.id
    private static let linkedKey = SettingsStore.keyPrefix + DisplaySettings.linkedLevel.id
    private static let positions = [0.30, 0.36, 0.42, 0.48, 0.54, 0.60, 0.66, 0.72, 0.78, 0.84].map(LevelPosition.init)

    private func harness() -> (EngineHarness, CountingDefaults) {
        let defaults = CountingDefaults()
        return (EngineHarness(defaults: defaults), defaults)
    }

    /// What a fresh store reading `defaults` would load: what is on disk.
    private func stored(_ defaults: UserDefaults, _ key: DisplayKey) -> LevelPosition? {
        SettingsStore(defaults: defaults)[DisplaySettings.perDisplay][key]?.level
    }

    /// Ten steps in one second: each is stored at once (and reduced with), one `defaults` write follows 0.5 s after the
    /// last.
    @Test func tenStepsInASecondWriteDefaultsOnce() async throws {
        let (h, defaults) = harness()
        await h.start(on: true)
        #expect(await h.boost())
        let before = defaults.writes(of: Self.perDisplayKey)
        let tasks = h.engine.levelPersistTaskCount
        for position in Self.positions {
            h.engine.setLevel(position, for: h.builtIn, source: .panel)
            #expect(h.settings[DisplaySettings.perDisplay][h.builtIn]?.level == position)
            #expect(h.engine.storedLevel(of: h.builtIn) == position)
            #expect(h.inputs.last?.displays.first?.preferences.level == position)
            await h.advance(.milliseconds(100))
        }
        #expect(defaults.writes(of: Self.perDisplayKey) == before)
        #expect(stored(defaults, h.builtIn) != Self.positions.last)
        #expect(h.engine.levelPersistTaskCount == tasks + 1)               // one task for the whole drag
        await h.advance(EngineTiming.levelPersistDelay)
        #expect(defaults.writes(of: Self.perDisplayKey) == before + 1)
        #expect(stored(defaults, h.builtIn) == Self.positions.last)
        #expect(!h.engine.activeTaskNames.contains("levelPersist"))
    }

    /// Linked levels coalesce the same way.
    @Test func linkedStepsWriteDefaultsOnce() async throws {
        let (h, defaults) = harness()
        h.settings[DisplaySettings.linkLevels] = true
        await h.start(on: true)
        let before = defaults.writes(of: Self.linkedKey)
        for position in Self.positions {
            h.engine.setLevel(position, for: nil, source: .panel)
            #expect(h.settings[DisplaySettings.linkedLevel] == position)
            await h.advance(.milliseconds(100))
        }
        #expect(defaults.writes(of: Self.linkedKey) == before)
        await h.advance(EngineTiming.levelPersistDelay)
        #expect(defaults.writes(of: Self.linkedKey) == before + 1)
        #expect(SettingsStore(defaults: defaults)[DisplaySettings.linkedLevel] == Self.positions.last)
    }

    /// Quit's `stopNow()` right after a step writes it.
    @Test func stopNowRightAfterAStepPersistsIt() async throws {
        let (h, defaults) = harness()
        await h.start(on: true)
        h.engine.setLevel(Self.positions[3], for: h.builtIn, source: .panel)
        h.engine.stopNow()
        #expect(stored(defaults, h.builtIn) == Self.positions[3])
        #expect(h.engine.activeTaskCount == 0)
    }

    /// Quit's `stopNow()` writes every baseline before the levels it owes: the settings write never delays the restore.
    @Test func stopNowRestoresBeforeItWritesTheLevels() async throws {
        let (h, defaults) = harness()
        await h.start(on: true)
        #expect(await h.boost())
        h.engine.setLevel(Self.positions[3], for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(100))
        let base = try #require(h.base())
        #expect(h.table()?.matches(base, tolerance: 1e-6) == false)       // scaled when the quit comes
        let gamma = h.gamma, display = h.id(h.builtIn), levelsKey = Self.perDisplayKey
        let tablesAtWrite = OSAllocatedUnfairLock<[GammaTable?]>(initialState: [])
        defaults.observeWrites { key in
            guard key == levelsKey else { return }
            let table = gamma.table(of: display)
            tablesAtWrite.withLock { $0.append(table) }
        }
        h.engine.stopNow()
        let tables = tablesAtWrite.withLock { $0 }
        #expect(tables.count == 1)
        #expect(tables.allSatisfy { $0?.matches(base, tolerance: 1e-6) == true })
        #expect(stored(defaults, h.builtIn) == Self.positions[3])
    }

    /// The ramped stop, a turn-off and Back to Standard write what is owed at once.
    @Test func stopTurnOffAndBackToStandardPersistAtOnce() async throws {
        let (h, defaults) = harness()
        await h.start(on: true)
        h.engine.setLevel(Self.positions[1], for: h.builtIn, source: .panel)
        h.engine.setOn(false, source: .panel)
        #expect(stored(defaults, h.builtIn) == Self.positions[1])
        h.engine.setLevel(Self.positions[2], for: h.builtIn, source: .panel)
        h.engine.returnToStandard(source: .shortcut)
        #expect(stored(defaults, h.builtIn) == Self.positions[2])
        h.engine.setLevel(Self.positions[4], for: h.builtIn, source: .panel)
        await h.engine.stop()
        #expect(stored(defaults, h.builtIn) == Self.positions[4])
        #expect(h.engine.activeTaskCount == 0)
    }

    /// A step costs one reduction: the settings change it made is the one it reduced with, so the observed-inputs
    /// re-reduction is skipped; a change made elsewhere still re-reduces.
    @Test func aStepCostsOneReduction() async throws {
        let (h, _) = harness()
        await h.start(on: true)
        #expect(await h.boost())
        await h.advance(.seconds(1))
        let reductions = h.inputs.count
        h.engine.setLevel(Self.positions[5], for: h.builtIn, source: .panel)
        await h.settle()
        #expect(h.inputs.count == reductions + 1)
        h.setPreferences { $0.capMode = .peak }                          // the Settings pane, say
        await h.settle()
        #expect(h.inputs.count == reductions + 2)
    }

    /// A plain write of the key (the UI, Settings) writes at once and settles what the steps owed, keeping both.
    @Test func aPlainWriteSettlesTheOwedOne() async throws {
        let (h, defaults) = harness()
        await h.start(on: true)
        h.engine.setLevel(Self.positions[6], for: h.builtIn, source: .panel)
        h.setPreferences { $0.oledNoticeAcknowledged = true }
        let fresh = SettingsStore(defaults: defaults)[DisplaySettings.perDisplay][h.builtIn]
        #expect(fresh?.level == Self.positions[6] && fresh?.oledNoticeAcknowledged == true)
        let writes = defaults.writes(of: Self.perDisplayKey)
        await h.advance(EngineTiming.levelPersistDelay)
        #expect(defaults.writes(of: Self.perDisplayKey) == writes)
    }
}
