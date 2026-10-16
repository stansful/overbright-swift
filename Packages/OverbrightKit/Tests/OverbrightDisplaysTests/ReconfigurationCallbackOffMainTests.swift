// OverbrightDisplaysTests/ReconfigurationCallbackOffMainTests.swift — the C reconfiguration callback is safe on any
// thread (ARCHITECTURE.md §7.1 "each such file … has one test that invokes the entry point from a background queue",
// §8.1 rule 2): called from a background queue it touches no main-actor state there and delivers on the main thread;
// a nil context or a released receiver delivers nothing. Calls the registered function pointer directly; nothing is
// registered with CoreGraphics.
import CoreGraphics
import Dispatch
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightDisplays

/// Records deliveries and the thread they arrived on.
private final class Recorder: ReconfigurationReceiver {
    private(set) var calls: [(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, onMain: Bool)] = []
    func reconfigured(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        calls.append((display, flags, Thread.isMainThread))
    }
}

@Suite struct ReconfigurationCallbackOffMainTests {
    /// Calls the C function on a background queue with `context` as its user info.
    private func callOffMain(_ display: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags,
                             context: ReconfigurationContext?) async {
        let address = context.map { UInt(bitPattern: Unmanaged.passUnretained($0).toOpaque()) } ?? 0
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                ReconfigurationCallback.function(display, flags, UnsafeMutableRawPointer(bitPattern: address))
                done.resume()
            }
        }
    }

    @Test func aBackgroundCallbackArrivesOnMain() async {
        let recorder = Recorder()
        let context = ReconfigurationContext(receiver: recorder)
        await callOffMain(7, .removeFlag, context: context)
        #expect(await eventually { recorder.calls.count == 1 })
        #expect(recorder.calls.first?.display == 7)
        #expect(recorder.calls.first?.flags == .removeFlag)
        #expect(recorder.calls.first?.onMain == true)
    }

    @Test func aBackgroundRemovalReachesTheDirectoryOnMain() async {
        let harness = await DirectoryHarness.started()
        let context = ReconfigurationContext(receiver: harness.model)
        await callOffMain(2, .removeFlag, context: context)
        #expect(await eventually { harness.events == [.displayRemoved(2)] })
        #expect(harness.model.displays.map(\.ref.id) == [1])
        // A burst from several threads: one began event, every removal.
        await callOffMain(1, .beginConfigurationFlag, context: context)
        await callOffMain(1, .beginConfigurationFlag, context: context)
        #expect(await eventually { harness.events.count == 2 })
        #expect(harness.events.last == .displayConfigurationBegan)
    }

    @Test func aMainThreadCallbackIsDeliveredAfterItReturns() async {
        let recorder = Recorder()
        let context = ReconfigurationContext(receiver: recorder)
        ReconfigurationCallback.function(3, .setModeFlag, Unmanaged.passUnretained(context).toOpaque())
        #expect(recorder.calls.isEmpty)                            // always hops: no reentrancy into CoreGraphics
        #expect(await eventually { recorder.calls.count == 1 })
        #expect(recorder.calls.first?.onMain == true)
    }

    @Test func noContextOrAReleasedReceiverDeliversNothing() async {
        await callOffMain(4, .removeFlag, context: nil)            // must not crash
        var recorder: Recorder? = Recorder()
        let context = ReconfigurationContext(receiver: recorder ?? Recorder())
        #expect(context.receiver != nil)
        recorder = nil
        #expect(context.receiver == nil)
        await callOffMain(4, .removeFlag, context: context)
        let marker = Recorder()
        let markerContext = ReconfigurationContext(receiver: marker)
        await callOffMain(5, .removeFlag, context: markerContext)
        // Deliveries keep their order on the main queue: once the marker arrived, the earlier one would have too.
        #expect(await eventually { marker.calls.count == 1 })
    }
}
