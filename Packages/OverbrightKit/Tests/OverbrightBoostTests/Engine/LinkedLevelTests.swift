// OverbrightBoostTests/Engine/LinkedLevelTests.swift — "Same level on all displays" (ARCHITECTURE.md §4.9, §5.3): one
// stored level mapped through each display's own ceiling, so Max means each display's own maximum; multipliers per
// display, clamped to each display's top; steps in stops from the display under the pointer.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct LinkedLevelTests {
    private let msi = DisplayFixture.Keys.mpg322ux
    private let tops = [DisplayFixture.Keys.builtIn: 1000.0 / 600, DisplayFixture.Keys.mpg322ux: 1.3]

    private func twoDisplays(linked: Bool) async -> EngineHarness {
        let h = EngineHarness(fixture: .russianNames, reducer: ReferenceReducer(tops: tops))
        h.settings[DisplaySettings.linkLevels] = linked
        await h.start()
        return h
    }

    @Test func linkedLevelMapsThroughEachDisplaysOwnTop() async throws {
        let h = await twoDisplays(linked: true)
        h.engine.setLevel(LevelPreset.max.position, for: nil, source: .panel)
        #expect(h.settings[DisplaySettings.linkedLevel] == LevelPreset.max.position)
        #expect(await h.boost(h.builtIn))
        #expect(await h.boost(msi))
        await h.advance(.milliseconds(400))
        #expect(abs((h.displayStatus(h.builtIn)?.appliedGain ?? 0) - 1000.0 / 600) < 1e-9)
        #expect(abs((h.displayStatus(msi)?.appliedGain ?? 0) - 1.3) < 1e-9)
    }

    @Test func movingOneLinkedSliderMovesAll() async throws {
        let h = await twoDisplays(linked: true)
        h.engine.setLevel(LevelPreset.indoor.position, for: msi, source: .panel)
        #expect(h.settings[DisplaySettings.linkedLevel] == LevelPreset.indoor.position)
        #expect(h.settings[DisplaySettings.perDisplay].isEmpty)
        #expect(await h.boost(h.builtIn))
        #expect(await h.boost(msi))
        #expect(abs((h.displayStatus(h.builtIn)?.appliedGain ?? 0) - pow(1000.0 / 600, 0.25)) < 1e-9)
        #expect(abs((h.displayStatus(msi)?.appliedGain ?? 0) - pow(1.3, 0.25)) < 1e-9)
    }

    @Test func unlinkedLevelsAreIndependent() async throws {
        let h = await twoDisplays(linked: false)
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPosition(-0.5), for: msi, source: .panel)
        #expect(await h.boost(h.builtIn))
        await h.advance(.milliseconds(400))
        #expect(h.phase(msi) == .dimmed)
        #expect(h.settings[DisplaySettings.perDisplay][msi]?.level == LevelPosition(-0.5))
    }

    /// A multiplier sets each display's own position for that gain, clamped to its top.
    @Test func multiplierPerDisplayClampedToItsTop() async throws {
        let h = await twoDisplays(linked: false)
        h.engine.setOn(true, source: .panel)
        await h.settle()                                                  // a decision gives each display its top
        h.engine.setExtraBrightness(.multiplier(1.5), for: nil, source: .intent)
        #expect(await h.boost(h.builtIn))
        #expect(await h.boost(msi))
        await h.advance(.milliseconds(400))
        #expect(abs((h.displayStatus(h.builtIn)?.appliedGain ?? 0) - 1.5) < 1e-9)
        #expect(abs((h.displayStatus(msi)?.appliedGain ?? 0) - 1.3) < 1e-9)
        h.engine.setExtraBrightness(.preset(.indoor), for: msi, source: .intent)
        #expect(h.settings[DisplaySettings.perDisplay][msi]?.level == LevelPreset.indoor.position)
    }

    /// Linked, a multiplier sets the one linked level, read on the named display (else the built-in one).
    @Test func linkedMultiplierSetsTheLinkedLevel() async throws {
        let h = await twoDisplays(linked: true)
        h.engine.setOn(true, source: .panel)
        await h.settle()
        h.engine.setExtraBrightness(.multiplier(1.2), for: nil, source: .intent)
        let expected = log(1.2) / log(1000.0 / 600)
        #expect(abs(h.settings[DisplaySettings.linkedLevel].value - expected) < 1e-9)
        h.engine.setExtraBrightness(.multiplier(1.2), for: msi, source: .intent)
        #expect(abs(h.settings[DisplaySettings.linkedLevel].value - log(1.2) / log(1.3)) < 1e-9)
        #expect(h.settings[DisplaySettings.perDisplay].isEmpty)
    }

    /// Brighter / Less Bright move the display under the pointer by a quarter stop (or 1/12 with the fine size).
    @Test func stepsMoveInStopsFromThePointersDisplay() async throws {
        let h = await twoDisplays(linked: false)
        h.engine.pointerDisplay = { _ in DisplayFixture.Keys.mpg322ux }
        h.engine.setOn(true, source: .panel)
        await h.settle()
        let before = h.engine.storedLevel(of: msi)
        h.engine.step(.brighter, source: .shortcut)
        let stops = StepMath.stops(at: h.engine.storedLevel(of: msi), top: 1.3) - StepMath.stops(at: before, top: 1.3)
        #expect(abs(stops - 0.25) < 1e-9 || h.engine.storedLevel(of: msi) == LevelPreset.max.position)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPreset.brightRoom.position)
        h.settings[ShortcutSettings.stepSize] = .fine
        h.engine.setLevel(LevelPosition(-0.3), for: msi, source: .panel)
        h.engine.step(.lessBright, source: .shortcut)
        let dimStops = StepMath.stops(at: h.engine.storedLevel(of: msi), top: 1.3)
            - StepMath.stops(at: LevelPosition(-0.3), top: 1.3)
        #expect(abs(dimStops + 1.0 / 12) < 1e-9)
    }

    /// While off, Less Bright starts from Standard (it never brightens) and turns the master on.
    @Test func lessBrightWhileOffDims() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.step(.lessBright, source: .shortcut)
        #expect(h.engine.status.isOn)
        #expect(h.engine.storedLevel(of: h.builtIn).isDim)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
    }
}
