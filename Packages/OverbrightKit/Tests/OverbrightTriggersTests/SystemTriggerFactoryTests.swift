// OverbrightTriggersTests/SystemTriggerFactoryTests.swift — the real factory over test doubles: availability, one
// handle type per strategy, the errors the ladder escalates on, `openWindowCount` (diagnostics `triggerWindows`) and
// the stop backstop; T4 and T4-alt edge cases. ARCHITECTURE.md §3.6, §4.3, §4.6, §4.7, §7.4, §8.4, §10.5.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightTriggers

@Suite struct SystemTriggerFactoryTests {
    nonisolated private static let onTwentySix = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26

    @Test func availabilityFollowsTheOSAndTheLegacySwitch() {
        let bed = TriggerTestBed()
        #expect(bed.factory.isAvailable(.taggedLayer) == Self.onTwentySix)
        for strategy in [TriggerStrategy.metalOneShot, .metalKeepAlive, .hlgSampleBuffer, .hlgStill] {
            #expect(bed.factory.isAvailable(strategy), "\(strategy)")
        }
        #expect(TriggerTestBed(allowsLegacyLayerPath: true).factory.isAvailable(.taggedLayer))
    }

    @Test func eachStrategyGetsItsOwnHandleAndNoWindowYet() throws {
        let bed = TriggerTestBed()
        var strategies: [TriggerStrategy] = [.metalOneShot, .metalKeepAlive, .hlgSampleBuffer, .hlgStill]
        if Self.onTwentySix { strategies.append(.taggedLayer) }
        var handles: [any TriggerHandle] = []
        for strategy in strategies {
            let request = TriggerTestBed.request(strategy, pixel: .bright, placement: .notch, blend: .softLight, tag: 4)
            let handle = try bed.factory.makeTrigger(request, on: TriggerTestBed.builtIn)
            #expect(handle.request == request)
            #expect(!handle.isOccluded)
            switch strategy {
            case .taggedLayer: #expect(handle is TaggedLayerTrigger)
            case .metalOneShot, .metalKeepAlive: #expect(handle is MetalClearTrigger)
            case .hlgStill: #expect(handle is HLGStillTrigger)
            case .hlgSampleBuffer: #expect(handle is HLGSampleBufferTrigger)
            }
            handles.append(handle)
        }
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(bed.factory.openWindowCount == 0)
        #expect(FileManager.default.fileExists(atPath: bed.cacheDirectory.path) == false, "no still is made early")
        handles.forEach { $0.remove() }
    }

    @Test(.enabled(if: !onTwentySix))
    func t1BeforeMacOS26NeedsANewerSystem() {
        let bed = TriggerTestBed()
        #expect(throws: TriggerError.needsNewerMacOS(26)) {
            _ = try bed.factory.makeTrigger(TriggerTestBed.request(.taggedLayer), on: TriggerTestBed.builtIn)
        }
    }

    @Test func anUnknownDisplayIsGone() {
        let bed = TriggerTestBed()
        let gone = DisplayRef(key: DisplayKey(rawValue: "00000000-0000-0000-0000-000000000099"), id: 99)
        for strategy in TriggerStrategy.allCases {
            #expect(throws: TriggerError.displayGone) {
                _ = try bed.factory.makeTrigger(TriggerTestBed.request(strategy), on: gone)
            }
        }
        #expect(throws: TriggerError.displayGone) { _ = try bed.factory.makeOverlay(on: gone) }
    }

    @Test func metalStrategiesWithoutADeviceThrowAndTheOthersDoNot() throws {
        let bed = TriggerTestBed()
        bed.hasMetalDevice = false
        for strategy in [TriggerStrategy.metalOneShot, .metalKeepAlive] {
            #expect(throws: TriggerError.noMetalDevice) {
                _ = try bed.factory.makeTrigger(TriggerTestBed.request(strategy), on: TriggerTestBed.builtIn)
            }
        }
        let still = try bed.factory.makeTrigger(TriggerTestBed.request(.hlgStill), on: TriggerTestBed.builtIn)
        still.remove()
    }

    @Test func openWindowCountFollowsPresentsRemovalsAndDroppedHandles() async throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let t2 = try bed.factory.makeTrigger(TriggerTestBed.request(.metalOneShot), on: TriggerTestBed.builtIn)
        var t3: (any TriggerHandle)? = try bed.factory.makeTrigger(TriggerTestBed.request(.metalKeepAlive),
                                                                   on: TriggerTestBed.external)
        let overlay = try bed.factory.makeOverlay(on: TriggerTestBed.builtIn)
        #expect(bed.factory.openWindowCount == 0)
        #expect(await t2.present(.black))
        #expect(bed.factory.openWindowCount == 1)
        #expect(await t3?.present(.bright) == true)
        try overlay.setFactor(1, headroomRequest: 1.2)
        #expect(bed.factory.openWindowCount == 3)
        t2.remove()
        #expect(bed.factory.openWindowCount == 2)
        t3 = nil   // the engine dropped it without remove(): its window goes with it
        #expect(bed.factory.openWindowCount == 1)
        #expect(bed.presenter.orderedOut.count == 2)
        overlay.remove()
        #expect(bed.factory.openWindowCount == 0)
    }

    @Test func stoppingRemovesEveryWindowTheEngineLeftBehind() async throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let t3 = try bed.factory.makeTrigger(TriggerTestBed.request(.metalKeepAlive), on: TriggerTestBed.builtIn)
        let overlay = try bed.factory.makeOverlay(on: TriggerTestBed.external)
        #expect(await t3.present(.bright))
        try overlay.setFactor(0.8, headroomRequest: 1)
        #expect(await eventually { bed.time.sleeperCount == 1 })
        #expect(bed.factory.openWindowCount == 2)
        await bed.factory.stop()
        #expect(bed.factory.openWindowCount == 0)
        let allReleased = bed.surfaces.allSatisfy { $0.isReleased }
        #expect(allReleased)
        #expect(bed.presenter.orderedOut.count == 2)
        #expect(await eventually { bed.time.sleeperCount == 0 }, "T3's keep-alive ended")
        #expect(await t3.present(.bright) == false)
        bed.factory.stopNow()
        #expect(bed.presenter.orderedOut.count == 2)
        #expect(bed.factory.serviceName == "triggers")
    }

    @Test func stopNowIsTheSameBackstopSynchronously() async throws {
        let bed = TriggerTestBed()
        let t2 = try bed.factory.makeTrigger(TriggerTestBed.request(.metalOneShot), on: TriggerTestBed.builtIn)
        #expect(await t2.present(.black))
        bed.factory.stopNow()
        #expect(bed.factory.openWindowCount == 0)
        #expect(bed.surfaces.first?.isReleased == true)
    }

    @Test func startDoesNothing() async {
        let bed = TriggerTestBed()
        await bed.factory.start()
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(bed.surfaceRequests.isEmpty)
        #expect(bed.screens.geometryLookups == 0)
        #expect(bed.time.sleeperCount == 0)
    }

    // MARK: T4 and T4-alt

    @Test func t4WithoutAStillPresentsNothing() async throws {
        let bed = TriggerTestBed(codecs: [])
        let still = try bed.factory.makeTrigger(TriggerTestBed.request(.hlgStill), on: TriggerTestBed.builtIn)
        #expect(await still.present(.black) == false)
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(bed.factory.openWindowCount == 0)
    }

    @Test func t4RemovedWhileItsStillIsMadeNeverOpensAWindow() async throws {
        let bed = TriggerTestBed(codecs: [.proRes422])
        let still = try bed.factory.makeTrigger(TriggerTestBed.request(.hlgStill), on: TriggerTestBed.builtIn)
        let present = Task { await still.present(.black) }
        #expect(await eventually { bed.stills.generations == 1 }, "the present waits for its still")
        still.remove()
        #expect(await present.value == false)
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(bed.factory.openWindowCount == 0)
    }

    @Test func t4AltAfterRemoveOrWithoutAScreenPresentsNothing() async throws {
        let bed = TriggerTestBed()
        let removed = try bed.factory.makeTrigger(TriggerTestBed.request(.hlgSampleBuffer), on: TriggerTestBed.builtIn)
        removed.remove()
        #expect(await removed.present(.black) == false)
        let gone = try bed.factory.makeTrigger(TriggerTestBed.request(.hlgSampleBuffer), on: TriggerTestBed.external)
        bed.screens.screens[TriggerTestBed.external.id] = nil
        #expect(await gone.present(.black) == false)
        #expect(bed.presenter.orderedIn.isEmpty)
        gone.remove()
    }

    @Test func hlgStrategiesIgnoreHeadroomRequests() throws {
        let bed = TriggerTestBed()
        for strategy in [TriggerStrategy.hlgStill, .hlgSampleBuffer] {
            let handle = try bed.factory.makeTrigger(TriggerTestBed.request(strategy, tag: 4), on: TriggerTestBed.builtIn)
            handle.requestHeadroom(1.2)
            handle.represent()
            #expect(handle.request.headroomTag == 4)
            #expect(bed.presenter.orderedIn.isEmpty)
            handle.remove()
        }
    }
}
