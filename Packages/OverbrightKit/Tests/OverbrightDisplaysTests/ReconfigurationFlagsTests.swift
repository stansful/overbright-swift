// OverbrightDisplaysTests/ReconfigurationFlagsTests.swift — what the directory does with reconfiguration callbacks
// (ARCHITECTURE.md §4.3, §7.1, §10.4; D9), on a `ManualTimeSource`: the begin flag reports
// `displayConfigurationBegan` once per burst and queries nothing; the remove flag reports `displayRemoved(id)` and
// drops the display at once, before any debounce; the after phase is debounced 0.5 s and confirmed at 2 s; screen
// parameter changes refresh the NSScreen facts only while no pass is pending (what they read:
// `ScreenParametersRefreshTests`).
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct ReconfigurationFlagsTests {
    // MARK: Phases

    @Test func flagsMapToPhases() {
        #expect(ReconfigurationPhase(flags: .beginConfigurationFlag) == .began)
        #expect(ReconfigurationPhase(flags: [.beginConfigurationFlag, .removeFlag]) == .began)
        #expect(ReconfigurationPhase(flags: .removeFlag) == .removed)
        #expect(ReconfigurationPhase(flags: [.removeFlag, .setMainFlag]) == .removed)
        #expect(ReconfigurationPhase(flags: .disabledFlag) == .removed)
        for flags: CGDisplayChangeSummaryFlags in [.addFlag, .setModeFlag, .movedFlag, .setMainFlag, .mirrorFlag,
                                                   .unMirrorFlag, .enabledFlag, .desktopShapeChangedFlag, []] {
            #expect(ReconfigurationPhase(flags: flags) == .changed, "\(flags)")
        }
    }

    // MARK: Begin flag

    @Test func beginFlagReportsOncePerBurstAndQueriesNothing() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        let screenReads = harness.raw.screenReads
        let generation = harness.model.generation
        harness.callback(1, .beginConfigurationFlag)
        harness.callback(2, .beginConfigurationFlag)
        #expect(harness.events == [.displayConfigurationBegan])
        #expect(harness.raw.reads == reads)                       // no display query in the begin phase
        #expect(harness.raw.screenReads == screenReads)
        #expect(harness.model.generation == generation)
        // The after phase ends the burst; the next burst reports again.
        harness.callback(1, .setModeFlag)
        await harness.advance(.seconds(2))
        harness.callback(1, .beginConfigurationFlag)
        #expect(harness.events.filter { $0 == .displayConfigurationBegan }.count == 2)
    }

    @Test func aBeginWithoutAfterPhaseSettlesByItself() async {
        let harness = await DirectoryHarness.started()
        harness.callback(1, .beginConfigurationFlag)
        await harness.advance(ReconfigurationPipeline.unfinishedBeginTimeout - .milliseconds(1))
        #expect(harness.reconfiguredCount == 0)
        await harness.advance(.milliseconds(1))
        #expect(harness.reconfiguredCount == 1)                   // the engine still gets its pass
        harness.callback(1, .beginConfigurationFlag)
        #expect(harness.events.filter { $0 == .displayConfigurationBegan }.count == 2)
    }

    // MARK: Remove flag

    @Test func removeFlagIsImmediate() async {
        let harness = await DirectoryHarness.started()
        let generation = harness.model.generation
        harness.raw.displays = [RawDisplayFixtures.builtIn()]
        harness.callback(2, .removeFlag)
        // Before any time passes: the event, then the list without the display.
        #expect(harness.events == [.displayRemoved(2)])
        #expect(harness.listedAtEvent == [[1, 2]])               // observers saw the event before the list changed
        #expect(harness.model.displays.map(\.ref.id) == [1])
        #expect(harness.model.generation == generation + 1)
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux) == nil)
        // The after phase follows, debounced.
        await harness.advance(.milliseconds(500))
        #expect(harness.events == [.displayRemoved(2), .displaysReconfigured])
        #expect(harness.model.generation == generation + 1)      // the pass found the same list
    }

    @Test func disabledFlagCountsAsRemoval() async {
        let harness = await DirectoryHarness.started()
        harness.callback(1, .disabledFlag)                        // the lid closed with an external attached
        #expect(harness.events == [.displayRemoved(1)])
        #expect(harness.model.displays.map(\.ref.id) == [2])
    }

    @Test func removingAnUnlistedDisplayIsStillReported() async {
        let harness = await DirectoryHarness.started()
        let generation = harness.model.generation
        harness.callback(77, .removeFlag)
        #expect(harness.events == [.displayRemoved(77)])
        #expect(harness.model.generation == generation)
    }

    // MARK: After phase

    @Test func afterPhaseIsDebounced() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        harness.callback(1, .setModeFlag)
        await harness.advance(.milliseconds(300))
        harness.callback(2, .movedFlag)
        await harness.advance(.milliseconds(499))
        #expect(harness.reconfiguredCount == 0 && harness.raw.reads == reads)
        await harness.advance(.milliseconds(1))
        #expect(harness.events == [.displaysReconfigured])
        #expect(harness.raw.reads == reads + 1)
    }

    @Test func confirmingPassReportsOnlyAChange() async {
        let harness = await DirectoryHarness.started()
        harness.callback(1, .setModeFlag)
        await harness.advance(.milliseconds(500))
        #expect(harness.reconfiguredCount == 1)
        await harness.advance(.milliseconds(1500))               // 2 s: confirming pass, nothing changed
        #expect(harness.reconfiguredCount == 1)

        // A fact that lags (the external's NSScreen arrives late) is caught by the confirming pass.
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(potential: 1)]
        harness.callback(2, .addFlag)
        await harness.advance(.milliseconds(500))
        let generation = harness.model.generation
        #expect(harness.reconfiguredCount == 2)
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(name: "MSI (renamed)")]
        await harness.advance(.milliseconds(1500))
        #expect(harness.reconfiguredCount == 3)
        #expect(harness.model.generation == generation + 1)
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.name == "MSI (renamed)")
    }

    @Test func aNewCallbackRestartsBothPasses() async {
        let harness = await DirectoryHarness.started()
        harness.callback(1, .setModeFlag)
        await harness.advance(.milliseconds(500))                 // pass 1
        await harness.advance(.milliseconds(500))
        harness.callback(1, .setModeFlag)                         // t = 1.0
        await harness.advance(.milliseconds(1000))                // t = 2.0: the old confirmation is gone
        #expect(harness.reconfiguredCount == 2)                  // pass at 0.5 and the new pass at 1.5
        harness.raw.displays = [RawDisplayFixtures.builtIn()]
        await harness.advance(.milliseconds(1000))                // t = 3.0: confirmation of the second burst
        #expect(harness.reconfiguredCount == 3)
        #expect(harness.model.displays.map(\.ref.id) == [1])
    }

    @Test func aHotPluggedDisplayJoinsAfterTheDebounce() async {
        let harness = await DirectoryHarness.started(displays: [RawDisplayFixtures.builtIn()])
        harness.raw.displays = [RawDisplayFixtures.msi(), RawDisplayFixtures.builtIn()]
        harness.callback(2, .addFlag)
        #expect(harness.model.displays.count == 1)
        await harness.advance(.milliseconds(500))
        #expect(harness.model.displays.map(\.ref.id) == [1, 2])
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .oledExternal)
    }

    @Test func stopDropsPendingPasses() async {
        let harness = await DirectoryHarness.started()
        harness.callback(1, .setModeFlag)
        harness.model.cancelPending()
        await harness.advance(.seconds(10))
        #expect(harness.reconfiguredCount == 0)
        #expect(harness.time.sleeperCount == 0)                   // no task left waiting
    }

    // MARK: Screen parameters

    @Test func screenParametersRefreshTheFactsUnlessAPassIsPending() async {
        let harness = await DirectoryHarness.started()
        let generation = harness.model.generation
        // The same facts (a headroom change): no new generation, but the event.
        harness.model.screenParametersChanged()
        #expect(harness.events == [.screenParametersChanged])
        #expect(harness.model.generation == generation)
        // HDR switched off on the MSI: NSScreen's potential changes, the facts follow at once.
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(name: "MSI", potential: 1)]
        harness.model.screenParametersChanged()
        #expect(harness.model.generation == generation + 1)
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.name == "MSI")
        // During a reconfiguration the displays are in flux: event only, the pass reads everything.
        harness.callback(2, .setModeFlag)
        harness.raw.displays = [RawDisplayFixtures.builtIn()]
        let screenReads = harness.raw.screenReads
        harness.model.screenParametersChanged()
        #expect(harness.raw.screenReads == screenReads)          // nothing read while the pass is pending
        #expect(harness.model.displays.count == 2)
        #expect(harness.events.last == .screenParametersChanged)
        await harness.advance(.milliseconds(500))
        #expect(harness.model.displays.count == 1)
    }

    @Test func screenParameterRefreshReusesTheLastRegistryFacts() async {
        let harness = await DirectoryHarness.started()
        harness.registry.value = .unknown                          // read only by full passes
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .oledExternal)
        harness.callback(2, .setModeFlag)
        await harness.advance(.milliseconds(500))
        // Without IORegistry facts the MSI has no luminance: an HDR external by NSScreen's potential.
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .hdrExternal)
    }

    // MARK: Observers

    @Test func generationCountsOnlyChanges() async {
        let harness = await DirectoryHarness.started()
        #expect(harness.model.generation == 1)
        await harness.model.reload()
        await harness.model.reload()
        #expect(harness.model.generation == 1)
    }

    @Test func cancelledObserversHearNothing() async {
        let harness = await DirectoryHarness.started()
        #expect(harness.model.observerCount == 1)
        harness.stopObserving()
        #expect(harness.model.observerCount == 0)
        harness.callback(2, .removeFlag)
        #expect(harness.events.isEmpty)
        #expect(harness.model.displays.count == 1)
    }
}
