// OverbrightTriggersTests/MetalClearTriggerTests.swift — T2/T3 without a GPU: the first present retried every 50 ms
// for up to 2 s, T3's 0.2 s keep-alive as a stored task, superseded presents, re-presents, tag policy, and the device
// released on remove. ARCHITECTURE.md §4.6, §4.7, §8.1 rule 5, §10.5. `ManualTimeSource` drives every wait; the
// surface is scripted and the presenter only records.
import AppKit
import CoreGraphics
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightTriggers

@Suite struct MetalClearTriggerTests {
    private func make(_ bed: TriggerTestBed, _ strategy: TriggerStrategy = .metalOneShot,
                      on display: DisplayRef = TriggerTestBed.builtIn) throws -> (MetalClearTrigger, ScriptedClearSurface) {
        let handle = try bed.factory.makeTrigger(TriggerTestBed.request(strategy, pixel: .bright), on: display)
        let trigger = try #require(handle as? MetalClearTrigger)
        let surface = try #require(bed.surfaces.last)
        return (trigger, surface)
    }

    /// Starts `present` and waits until it sleeps (or finishes).
    private func startPresent(_ trigger: MetalClearTrigger, _ pixel: TriggerPixel, bed: TriggerTestBed,
                              sleepers: Int = 1) async -> Task<Bool, Never> {
        let task = Task { await trigger.present(pixel) }
        _ = await eventually { bed.time.sleeperCount >= sleepers }
        return task
    }

    @Test func aFirstPresentThatFailsIsRetriedEvery50ms() async throws {
        let bed = TriggerTestBed()
        bed.surfaceFailuresBeforeSuccess = 3
        let (trigger, surface) = try make(bed)
        let task = await startPresent(trigger, .bright, bed: bed)
        #expect(surface.attempts == 1)
        await bed.time.advance(by: .milliseconds(49))
        #expect(surface.attempts == 1, "no retry before 50 ms")
        await bed.time.advance(by: .milliseconds(101))
        #expect(await task.value)
        #expect(surface.attempts == 4)
        #expect(surface.presentedValues == [1.6])
        #expect(trigger.presentCount == 1)
        #expect(bed.presenter.orderedIn.count == 1)
    }

    @Test func aPresentThatNeverSucceedsGivesUpAfterTwoSeconds() async throws {
        let bed = TriggerTestBed()
        let (trigger, surface) = try make(bed)
        surface.alwaysFails = true
        let task = await startPresent(trigger, .black, bed: bed)
        await bed.time.advance(by: .milliseconds(1950))
        #expect(surface.attempts == 40)
        await bed.time.advance(by: .milliseconds(50))
        #expect(await task.value == false)
        #expect(surface.attempts == 41, "one attempt now and 40 retries, the last at 2 s")
        await bed.time.advance(by: .seconds(10))
        #expect(surface.attempts == 41)
        #expect(bed.time.sleeperCount == 0)
    }

    @Test func t3KeepsAliveFiveTimesASecondAndT2DoesNot() async throws {
        let bed = TriggerTestBed()
        let (t3, t3Surface) = try make(bed, .metalKeepAlive)
        #expect(await t3.present(.bright))
        #expect(t3.isKeepingAlive)
        #expect(t3Surface.presentedValues == [1.6])
        #expect(await eventually { bed.time.sleeperCount == 1 })
        await bed.time.advance(by: .milliseconds(190))
        #expect(t3Surface.presentedValues.count == 1)
        await bed.time.advance(by: .milliseconds(10))
        #expect(t3Surface.presentedValues.count == 2)
        await bed.time.advance(by: .seconds(1))
        #expect(t3Surface.presentedValues == Array(repeating: 1.6, count: 7))

        let (t2, t2Surface) = try make(bed, .metalOneShot, on: TriggerTestBed.external)
        #expect(await t2.present(.bright))
        #expect(!t2.isKeepingAlive)
        let sleepersWithoutT2 = bed.time.sleeperCount
        await bed.time.advance(by: .seconds(20))
        #expect(t2Surface.presentedValues == [1.6], "T2 presents again only on events")
        #expect(sleepersWithoutT2 == 1, "only T3's keep-alive sleeps")
        t3.remove()
        t2.remove()
    }

    @Test func removeCancelsTheKeepAliveReleasesTheDeviceAndClosesTheWindow() async throws {
        let bed = TriggerTestBed()
        let (trigger, surface) = try make(bed, .metalKeepAlive)
        #expect(await trigger.present(.bright))
        #expect(bed.factory.openWindowCount == 1)
        _ = await eventually { bed.time.sleeperCount == 1 }
        trigger.remove()
        #expect(surface.isReleased)
        #expect(!trigger.isKeepingAlive)
        #expect(bed.presenter.orderedOut.count == 1)
        #expect(bed.factory.openWindowCount == 0)
        #expect(await eventually { bed.time.sleeperCount == 0 })
        await bed.time.advance(by: .seconds(30))
        #expect(surface.presentedValues == [1.6])
        #expect(await trigger.present(.bright) == false, "a removed trigger never presents")
        trigger.remove()
        #expect(bed.presenter.orderedOut.count == 1, "remove is idempotent")
    }

    @Test func removeDuringTheRetriesEndsThePresentWithoutAFrame() async throws {
        let bed = TriggerTestBed()
        bed.surfaceFailuresBeforeSuccess = 5
        let (trigger, surface) = try make(bed)
        let task = await startPresent(trigger, .bright, bed: bed)
        trigger.remove()
        await bed.time.advance(by: .seconds(1))
        #expect(await task.value == false)
        #expect(surface.presentedValues.isEmpty)
    }

    @Test func aNewerPresentSupersedesARetryingOne() async throws {
        let bed = TriggerTestBed()
        bed.surfaceFailuresBeforeSuccess = 2
        let (trigger, surface) = try make(bed)
        let black = await startPresent(trigger, .black, bed: bed)
        let bright = await startPresent(trigger, .bright, bed: bed, sleepers: 2)
        await bed.time.advance(by: .milliseconds(50))
        #expect(await black.value == false)
        #expect(await bright.value)
        #expect(surface.presentedValues == [1.6])
        #expect(trigger.value == 1.6)
        #expect(bed.presenter.orderedIn.count == 1, "one window for both presents")
    }

    @Test func representPlacesTheWindowAgainAndPresentsOneMoreFrame() async throws {
        let bed = TriggerTestBed()
        let (trigger, surface) = try make(bed)
        trigger.represent()
        #expect(surface.attempts == 0, "nothing to re-present before the first present")
        #expect(await trigger.present(.black))
        var moved = TriggerTestBed.builtInGeometry
        moved.frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        bed.screens.screens[TriggerTestBed.builtIn.id] = moved
        trigger.represent()
        #expect(await eventually { surface.presentedValues.count == 2 })
        #expect(surface.presentedValues == [0, 0])
        #expect(bed.presenter.orderedIn.first?.frame == CGRect(x: 1799, y: 1168, width: 1, height: 1))
        trigger.remove()
    }

    @Test func theDefaultUntaggedLayerIgnoresHeadroomRequests() async throws {
        let bed = TriggerTestBed()
        let (trigger, surface) = try make(bed)
        #expect(await trigger.present(.bright))
        trigger.requestHeadroom(2)
        await Task.yield()
        #expect(surface.tags.isEmpty)
        #expect(trigger.headroomTag == 2)
        #expect(surface.presentedValues.count == 1)
        trigger.remove()
    }

    @Test func aTaggedLayerIsTaggedAtTheRequestAndReTaggedInPlace() async throws {
        let bed = TriggerTestBed(tagsMetalLayers: true)
        let (trigger, surface) = try make(bed)
        #expect(surface.tags == [16])
        #expect(await trigger.present(.bright))
        trigger.requestHeadroom(1.5)
        #expect(surface.tags == [16, 1.5])
        #expect(await eventually { surface.presentedValues.count == 2 }, "a re-tag presents again")
        #expect(bed.presenter.orderedIn.count == 1, "re-tagging opens no new window")
        trigger.remove()
    }

    @Test func aDisplayGoneBeforeThePresentOpensNothing() async throws {
        let bed = TriggerTestBed()
        let (trigger, surface) = try make(bed)
        bed.screens.screens[TriggerTestBed.builtIn.id] = nil
        #expect(await trigger.present(.bright) == false)
        #expect(surface.attempts == 0)
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(bed.factory.openWindowCount == 0)
    }

    @Test func drawablesMatchTheTriggerEdgeInPixels() throws {
        let bed = TriggerTestBed()
        _ = try bed.factory.makeTrigger(TriggerTestBed.request(.metalOneShot), on: TriggerTestBed.builtIn)
        _ = try bed.factory.makeTrigger(TriggerTestBed.request(.metalKeepAlive, edgePoints: 3), on: TriggerTestBed.external)
        #expect(bed.surfaceRequests.map(\.pixels) == [2, 3])
        #expect(bed.surfaceRequests.map(\.display) == [TriggerTestBed.builtIn.id, TriggerTestBed.external.id])
    }
}
