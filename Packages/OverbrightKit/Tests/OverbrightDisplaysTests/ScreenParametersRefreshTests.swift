// OverbrightDisplaysTests/ScreenParametersRefreshTests.swift — what a screen-parameters pass reads (ARCHITECTURE.md
// §7.1, §10.4 as built; energy D1), on counting fakes: the online IDs and the NSScreen facts every time; the
// CoreGraphics facts (UUID, capacity, the transfer-table read behind `tableReadable`, vendor, model, serial, mirror)
// only when the online IDs differ from the last read's. macOS posts the notification 4–5 times a second on average
// and up to 122 times a second in bursts (also on every headroom move), and only a reconfiguration, which has its own
// full passes, changes those facts.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct ScreenParametersRefreshTests {
    // MARK: Same displays

    @Test func anUnchangedPassReadsNoTable() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        let screenReads = harness.raw.screenReads
        let generation = harness.model.generation
        for _ in 0..<3 { harness.model.screenParametersChanged() }
        #expect(harness.raw.reads == reads)                       // no CoreGraphics facts, no table read
        #expect(harness.raw.screenReads == screenReads + 3)       // the online IDs and NSScreen, every time
        #expect(harness.model.generation == generation)
        #expect(harness.events == Array(repeating: .screenParametersChanged, count: 3))
    }

    @Test func aPotentialChangeIsStillPublished() async {
        // Without IORegistry facts the MSI's peak comes from NSScreen's potential (D8), so the change shows in the facts.
        let harness = DirectoryHarness(registry: .unknown)
        await harness.model.reload()
        let reads = harness.raw.reads
        let generation = harness.model.generation
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelPeakNits != nil)
        // HDR switched off on the MSI: only its NSScreen changes.
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(potential: 1)]
        harness.model.screenParametersChanged()
        #expect(harness.model.generation == generation + 1)
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelPeakNits == nil)
        #expect(harness.raw.reads == reads)
    }

    @Test func nameAndNotchFollowTheScreen() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        harness.raw.displays = [RawDisplayFixtures.builtIn(name: "Built-in (renamed)"), RawDisplayFixtures.msi()]
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.builtIn)?.name == "Built-in (renamed)")
        #expect(harness.model.facts(for: DisplayFixture.Keys.builtIn)?.hasNotch == true)
        // The built-in's screen goes away (a display in transition): the facts lose what only the screen gave.
        harness.raw.displays = [RawDisplayFixtures.builtIn(screen: false), RawDisplayFixtures.msi()]
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.builtIn)?.hasNotch == false)
        #expect(harness.raw.reads == reads)
    }

    @Test func theFactsOfTheLastReadAreKeptUntilAReconfiguration() async {
        // A CoreGraphics fact that changed without a reconfiguration is not read per notification; the
        // reconfiguration's own pass reads it, and later notifications keep the new value.
        let harness = await DirectoryHarness.started()
        var unreadable = RawDisplayFixtures.msi()
        unreadable.tableReadable = false
        harness.raw.displays = [RawDisplayFixtures.builtIn(), unreadable]
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .oledExternal)
        harness.callback(2, .setModeFlag)
        await harness.advance(.milliseconds(500))
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .virtualDisplay)
        let reads = harness.raw.reads
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.mpg322ux)?.panelClass == .virtualDisplay)
        #expect(harness.raw.reads == reads)
    }

    // MARK: Other displays

    @Test func aNewDisplayTriggersTheFullPass() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        let generation = harness.model.generation
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(), RawDisplayFixtures.sidecar]
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 1)
        #expect(harness.model.generation == generation + 1)
        #expect(harness.model.facts(for: DisplayFixture.Keys.sidecar)?.panelClass == .virtualDisplay)
        // The new read is the one later passes reuse.
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 1)
    }

    @Test func aDisplayThatWentAwayTriggersTheFullPass() async {
        let harness = await DirectoryHarness.started()
        let reads = harness.raw.reads
        harness.raw.displays = [RawDisplayFixtures.builtIn()]
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 1)
        #expect(harness.model.displays.map(\.ref.id) == [1])
    }

    @Test func aDisplayWithoutAUUIDIsTriedAgainOnEveryPass() async {
        // As before D1: a display left out for want of a UUID is looked for again on the next notification.
        let harness = await DirectoryHarness.started()
        harness.raw.withoutUUID = [RawDisplayFixtures.sidecar.id]
        harness.raw.displays = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi(), RawDisplayFixtures.sidecar]
        let reads = harness.raw.reads
        harness.model.screenParametersChanged()
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 2)
        #expect(harness.model.displays.count == 2)
        harness.raw.withoutUUID = []
        harness.model.screenParametersChanged()
        #expect(harness.model.facts(for: DisplayFixture.Keys.sidecar) != nil)
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 3)
    }

    @Test func aRemovedDisplayIsReadAgainIfItIsStillOnline() async {
        // The remove flag drops the display from the reused read too: should it still be listed online once the
        // pass is gone (stopped and started again), its CoreGraphics facts are read afresh, not taken from before.
        let harness = await DirectoryHarness.started()
        harness.callback(2, .removeFlag)
        #expect(harness.model.displays.map(\.ref.id) == [1])
        harness.model.cancelPending()
        let reads = harness.raw.reads
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == reads + 1)
        #expect(harness.model.displays.map(\.ref.id) == [1, 2])
    }

    @Test func beforeAnyFullPassTheFirstNotificationReadsEverything() {
        let harness = DirectoryHarness()
        harness.model.screenParametersChanged()
        #expect(harness.raw.reads == 1)
        #expect(harness.model.displays.map(\.ref.id) == [1, 2])
    }
}
