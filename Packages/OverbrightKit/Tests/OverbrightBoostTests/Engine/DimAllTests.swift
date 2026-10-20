// OverbrightBoostTests/Engine/DimAllTests.swift — Dim All Displays ⇄ Stop Dimming and "Dim below minimum"
// (ARCHITECTURE.md §4.9, §5.9; D11): every display that can dim goes to `lastDimLight`, previous levels remembered in
// memory and restored; no trigger and no headroom; virtual displays excluded; the master turns on.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct DimAllTests {
    private let msi = DisplayFixture.Keys.mpg322ux
    private var dimFactor: Double {
        FactorMath.tableFactor(forLightGain: LevelMapping.dimLight(for: LevelMapping.position(forDimLight: 0.25)),
                               domain: .encoded)
    }

    @Test func dimAllDimsEveryDisplayAndStopDimmingRestores() async throws {
        let h = EngineHarness(fixture: .russianNames)
        await h.start()
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPreset.indoor.position, for: msi, source: .panel)
        #expect(await h.boost(h.builtIn))
        h.engine.toggleDim(source: .menu)
        await h.advance(.milliseconds(900))
        #expect(h.phase(h.builtIn) == .dimmed && h.phase(msi) == .dimmed)
        #expect(abs((h.liveFactor(h.builtIn) ?? 0) - dimFactor) < 1e-4)
        #expect(abs((h.liveFactor(msi) ?? 0) - dimFactor) < 1e-4)
        #expect(h.liveTriggers(h.builtIn).isEmpty && h.liveTriggers(msi).isEmpty)
        h.engine.toggleDim(source: .menu)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPreset.sunlight.position)
        #expect(h.engine.storedLevel(of: msi) == LevelPreset.indoor.position)
        #expect(await h.boost(h.builtIn))
        #expect(h.orderViolations.isEmpty)
    }

    @Test func dimAllTurnsTheMasterOn() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.toggleDim(source: .shortcut)
        #expect(h.engine.status.isOn)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
        h.engine.toggleDim(source: .shortcut)                             // back to the stored Bright room
        #expect(await h.boost())
    }

    /// A virtual display (no transfer table) is never dimmed.
    @Test func virtualDisplaysAreLeftAlone() async throws {
        let h = EngineHarness(fixture: .sidecar)
        await h.start()
        let sidecar = h.settings[DisplaySettings.perDisplay][DisplayFixture.Keys.sidecar]
        h.engine.setOn(true, source: .panel)
        await h.settle()
        h.engine.toggleDim(source: .menu)
        await h.advance(.milliseconds(400))
        #expect(h.phase(h.builtIn) == .dimmed)
        #expect(h.phase(DisplayFixture.Keys.sidecar) == .idle)
        #expect(h.settings[DisplaySettings.perDisplay][DisplayFixture.Keys.sidecar] == sidecar)   // its level untouched
    }

    @Test func setDimLightClampsAndBecomesTheDimAllLight() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setDimLight(0.001, for: h.builtIn, source: .settings)
        #expect(h.settings[DisplaySettings.lastDimLight] == LevelMapping.minimumDimLight)
        #expect(h.engine.storedLevel(of: h.builtIn) == LevelPosition(-1))
        h.engine.setDimLight(1.5, for: nil, source: .settings)
        #expect(h.settings[DisplaySettings.lastDimLight] == 0.99)
        await h.advance(.milliseconds(400))
        #expect(abs((h.liveFactor() ?? 0) - FactorMath.tableFactor(forLightGain: 0.99, domain: .encoded)) < 1e-4)
    }

    /// Dimming needs no headroom: a display whose boost never arrives still dims.
    @Test func dimmingNeedsNoHeadroom() async throws {
        let h = EngineHarness(fixture: .mpg322uxHDROff)
        await h.start()
        h.engine.setDimLight(0.5, for: nil, source: .menu)
        await h.advance(.milliseconds(400))
        #expect(h.phase(DisplayFixture.Keys.mpg322ux) == .dimmed)
        #expect(h.triggers.made.isEmpty)
    }

    /// Two monitors with identical EDIDs can share a CoreGraphics UUID, so display keys may repeat: requests over
    /// every display never trap (§9.2).
    @Test func duplicateDisplayKeysNeverTrap() async throws {
        let h = EngineHarness(fixture: .russianNames)
        let shared = h.builtIn
        h.directory.setDisplays(h.directory.displays.map { facts in
            var facts = facts
            facts.ref.key = shared
            return facts
        })
        await h.start()
        h.engine.setLevel(LevelPreset.max.position, for: nil, source: .panel)
        h.engine.setExtraBrightness(.multiplier(1.5), for: nil, source: .panel)
        h.engine.setDimLight(0.5, for: nil, source: .menu)
        h.engine.toggleDim(source: .menu)
        h.engine.toggleDim(source: .menu)
        await h.advance(.seconds(1))
        #expect(h.engine.status.isOn && h.engine.status.displays.count == 2)
    }

    @Test func linkedDimAllUsesTheLinkedLevel() async throws {
        let h = EngineHarness(fixture: .russianNames)
        h.settings[DisplaySettings.linkLevels] = true
        await h.start()
        h.engine.toggleDim(source: .menu)
        #expect(h.settings[DisplaySettings.linkedLevel] == LevelMapping.position(forDimLight: 0.25))
        h.engine.toggleDim(source: .menu)
        #expect(h.settings[DisplaySettings.linkedLevel] == LevelPreset.brightRoom.position)
    }
}
