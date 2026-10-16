// OverbrightBoostTests/Engine/HUDChangeTests.swift — `status.lastChange` for the HUD (ARCHITECTURE.md §4.9; DESIGN.md
// §6): `.level` for shortcuts, intents, the Focus filter and Back to Standard (never for the panel, the menu or
// Settings); `.preparing` when an icon, shortcut or intent turn-on is not ready within 0.5 s; `.blocked(reason)` when a
// guard stops such a request; `.automationStopped` / `.automationResumed` for battery, Low Power, heat and the schedule;
// never for full-screen, app or game pauses.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct HUDChangeTests {
    private func onBattery(_ percent: Int) -> PowerState {
        PowerState(source: .battery, batteryPercent: percent, isLowPowerMode: false)
    }

    @Test func levelChangesFromShortcutsIntentsAndFocusOnly() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPreset.indoor.position, for: h.builtIn, source: .menu)
        h.engine.setLevel(LevelPreset.indoor.position, for: h.builtIn, source: .settings)
        #expect(h.engine.status.lastChange == nil)
        h.engine.step(.brighter, source: .shortcut)
        let first = try #require(h.engine.status.lastChange)
        #expect(first.kind == .level && first.source == .shortcut && first.sequence == 1)
        h.engine.setExtraBrightness(.preset(.max), for: nil, source: .intent)
        #expect(h.engine.status.lastChange?.source == .intent && h.engine.status.lastChange?.sequence == 2)
    }

    @Test func backToStandardFromAnySourceShows() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.engine.returnToStandard(source: .menu)
        let change = try #require(h.engine.status.lastChange)
        #expect(change.kind == .level && change.source == .menu)
    }

    @Test func turnOnNotReadyWithinHalfASecondShowsPreparing() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .statusItem)
        await h.advance(.milliseconds(400))
        #expect(h.engine.status.lastChange == nil)
        #expect(h.engine.status.symbol == .preparing)
        await h.advance(.milliseconds(150))
        #expect(h.engine.status.lastChange?.kind == .preparing)
        #expect(h.engine.status.lastChange?.source == .statusItem)
        #expect(await h.boost())
        #expect(h.engine.status.symbol == .on)
    }

    @Test func panelTurnOnNeverShowsPreparing() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.engine.status.lastChange == nil)
    }

    @Test func guardBlocksARequestedBoost() async throws {
        let h = EngineHarness(decide: GuardingReducer().decide)
        h.signals.snapshot.power = onBattery(12)
        await h.start()
        h.engine.setOn(true, source: .shortcut)
        let change = try #require(h.engine.status.lastChange)
        #expect(change.kind == .blocked(.battery(percent: 12, threshold: 20)))
        #expect(h.signals.refreshPowerNowCount >= 1)                      // read before the reduction
        h.engine.setDimLight(0.5, for: nil, source: .shortcut)            // dimming is never blocked
        #expect(h.engine.status.lastChange?.kind == .level)
    }

    /// The battery guard stops a visible boost and later lets it come back: stopped, then resumed.
    @Test func automationsStopAndResume() async throws {
        let h = EngineHarness(decide: GuardingReducer().decide)
        h.signals.snapshot.power = onBattery(60)
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.power = onBattery(15)
        await h.advance(.milliseconds(100))
        #expect(h.engine.status.lastChange?.kind == .automationStopped(.battery(percent: 15, threshold: 20)))
        let stopped = try #require(h.engine.status.lastChange?.sequence)
        h.signals.snapshot.power = onBattery(14)                          // the same automation: no new change
        await h.advance(.milliseconds(100))
        #expect(h.engine.status.lastChange?.sequence == stopped)
        h.signals.snapshot.power = PowerState(source: .adapter, batteryPercent: 14, isLowPowerMode: false)
        await h.advance(.milliseconds(100))
        #expect(h.engine.status.lastChange?.kind == .automationResumed)
        #expect(await h.boost())
    }

    @Test func heatCapIsAnAutomationChange() async throws {
        let h = EngineHarness(decide: GuardingReducer().decide)
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.thermal = .serious
        await h.advance(.milliseconds(100))
        #expect(h.engine.status.lastChange?.kind == .automationStopped(.thermalSerious))
        await h.advance(.milliseconds(600))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - GainCeiling.thermalSeriousGain) < 1e-9)
    }

    /// Full-screen, app and game pauses are the user's own doing: no HUD.
    @Test func fullScreenPausesAreSilent() async throws {
        let h = EngineHarness(decide: { input in
            var decision = ReferenceReducer().decide(input)
            for (key, display) in decision.displays where input.system.fullScreenDisplays.contains(key) {
                var paused = display
                paused.target = .neutral
                paused.reasons = [.fullScreenApp]
                decision.displays[key] = paused
            }
            return decision
        })
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.fullScreenDisplays = [h.builtIn]
        await h.advance(.milliseconds(500))
        #expect(h.phase() == .idle)
        h.signals.snapshot.fullScreenDisplays = []
        #expect(await h.boost())
        #expect(h.engine.status.lastChange == nil)
    }

    /// A Focus filter that turns Overbright on turns the master on and shows the level.
    @Test func focusFilterOnTurnsOn() async throws {
        let h = EngineHarness()
        await h.start()
        h.signals.setFocusDirective(.on(level: LevelPreset.sunlight.position))
        await h.advance(.milliseconds(100))
        #expect(h.engine.status.isOn)
        #expect(h.engine.status.lastChange?.source == .focusFilter)
        #expect(await h.boost())
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - pow(ReferenceReducer.defaultTop, 0.75)) < 1e-9)
    }
}
