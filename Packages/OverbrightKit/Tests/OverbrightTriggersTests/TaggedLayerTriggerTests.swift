// OverbrightTriggersTests/TaggedLayerTriggerTests.swift — T1 as the engine drives it (macOS 26+): one window per
// trigger, re-colour and re-tag in place, re-placement, removal. ARCHITECTURE.md §3.6, §4.7 (rungs 1–2, tag policies
// A and B), §10.5. The presenter only records; no window reaches the screen.
import AppKit
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import QuartzCore
import Testing
@testable import OverbrightTriggers

/// Every test needs macOS 26 (T1's tagged colours), and is skipped before.
@Suite struct TaggedLayerTriggerTests {
    private func make(_ bed: TriggerTestBed, tag: Double = 16,
                      placement: TriggerPlacement = .topRightCorner) throws -> TaggedLayerTrigger {
        let request = TriggerTestBed.request(.taggedLayer, placement: placement, tag: tag)
        return try #require(try bed.factory.makeTrigger(request, on: TriggerTestBed.builtIn) as? TaggedLayerTrigger)
    }

    @available(macOS 26.0, *)
    @Test func presentBuildsOneTaggedLayerInOneWindow() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        #expect(bed.presenter.orderedIn.isEmpty, "making a trigger opens nothing")
        #expect(await trigger.present(.black))
        let window = try #require(bed.presenter.orderedIn.first)
        #expect(window.frame == CGRect(x: 1511, y: 981, width: 1, height: 1))
        let layer = try #require(trigger.layer)
        #expect(window.contentView?.layer === layer)
        #expect(layer.preferredDynamicRange == .high)
        #expect(layer.backgroundColor?.contentHeadroom == 16)
        #expect(layer.backgroundColor?.components?.first == 0)
        #expect(bed.factory.openWindowCount == 1)
        trigger.remove()
    }

    @available(macOS 26.0, *)
    @Test func aSecondPresentRecoloursInPlace() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        #expect(await trigger.present(.black))
        let layer = try #require(trigger.layer)
        #expect(await trigger.present(.bright))
        #expect(trigger.layer === layer)
        #expect(bed.presenter.orderedIn.count == 1)
        #expect(layer.backgroundColor?.components?.first == 1.6)
        #expect(layer.backgroundColor?.contentHeadroom == 16)
        #expect(trigger.shownPixel == .bright)
        trigger.remove()
    }

    @available(macOS 26.0, *)
    @Test func requestHeadroomReTagsTheSameLayerAndKeepsTheClamp() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        #expect(await trigger.present(.black))
        let layer = try #require(trigger.layer)
        trigger.requestHeadroom(1.3)
        #expect(abs(Double(layer.backgroundColor?.contentHeadroom ?? 0) - 1.3) < 1e-3)
        trigger.requestHeadroom(1.0)
        #expect(abs(Double(layer.backgroundColor?.contentHeadroom ?? 0) - 1.01) < 1e-3)
        #expect(layer.backgroundColor?.components?.first == 0, "re-tagging keeps the pixel")
        #expect(trigger.request.headroomTag == 16, "the rung itself is unchanged")
        #expect(bed.presenter.orderedIn.count == 1)
        trigger.remove()
    }

    @available(macOS 26.0, *)
    @Test func aLowRequestedTagIsClampedFromTheStart() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed, tag: 0)
        #expect(await trigger.present(.black))
        #expect(abs(Double(trigger.layer?.backgroundColor?.contentHeadroom ?? 0) - 1.01) < 1e-3)
        trigger.remove()
    }

    @available(macOS 26.0, *)
    @Test func representFollowsTheScreenAndKeepsTheColour() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed, placement: .notch)
        #expect(await trigger.present(.bright))
        let window = try #require(bed.presenter.orderedIn.first)
        #expect(window.frame == CGRect(x: 756, y: 981, width: 1, height: 1))
        var moved = TriggerTestBed.builtInGeometry
        moved.frame.origin.y = -982
        moved.auxiliaryTopLeftArea = moved.auxiliaryTopLeftArea?.offsetBy(dx: 0, dy: -982)
        moved.auxiliaryTopRightArea = moved.auxiliaryTopRightArea?.offsetBy(dx: 0, dy: -982)
        bed.screens.screens[TriggerTestBed.builtIn.id] = moved
        trigger.represent()
        #expect(window.frame == CGRect(x: 756, y: -1, width: 1, height: 1))
        #expect(trigger.layer?.backgroundColor?.components?.first == 1.6)
        #expect(bed.presenter.orderedIn.count == 1)
        trigger.remove()
    }

    @available(macOS 26.0, *)
    @Test func removeClosesTheWindowAndEndsTheTrigger() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        var screenReports: [CGDirectDisplayID?] = []
        trigger.onScreenChange = { screenReports.append($0) }
        #expect(await trigger.present(.black))
        let window = try #require(bed.presenter.orderedIn.first)
        trigger.remove()
        #expect(bed.presenter.orderedOut.first === window)
        #expect(trigger.layer == nil)
        #expect(bed.factory.openWindowCount == 0)
        #expect(await trigger.present(.black) == false)
        trigger.requestHeadroom(4)
        trigger.represent()
        #expect(bed.presenter.orderedIn.count == 1)
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        await Task.yield()
        #expect(screenReports.isEmpty, "a removed trigger reports nothing")
    }

    @available(macOS 26.0, *)
    @Test func aDisplayWithoutAScreenFailsThePresent() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        bed.screens.screens = [:]
        #expect(await trigger.present(.black) == false)
        #expect(trigger.layer == nil)
        #expect(bed.presenter.orderedIn.isEmpty)
    }

    @available(macOS 26.0, *)
    @Test func occlusionAndScreenCallbacksReachTheEngine() async throws {
        let bed = TriggerTestBed()
        let trigger = try make(bed)
        var occlusion: [Bool] = []
        var screens: [CGDirectDisplayID?] = []
        trigger.onOcclusionChange = { occlusion.append($0) }
        trigger.onScreenChange = { screens.append($0) }
        #expect(await trigger.present(.black))
        let window = try #require(bed.presenter.orderedIn.first)
        bed.screens.windowDisplay = TriggerTestBed.external.id
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        #expect(await eventually { screens.count == 1 && occlusion.count == 1 })
        #expect(screens == [TriggerTestBed.external.id])
        #expect(occlusion == [true])
        #expect(trigger.isOccluded)
        trigger.remove()
    }
}
