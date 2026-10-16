// OverbrightSignalsTests/OffMainTests.swift — every entry point the system may call off the main thread, called from a
// background queue (ARCHITECTURE.md §7.1 last paragraph, §8.1 rule 2, §9.2 rule 9). Under this module's default
// MainActor isolation a main-actor entry point would trap here before any hop could run; each suite shows the entry
// point survives and its main-actor work happens.
import AppKit
import CoreMediaIO
import Darwin
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightSignals

/// A main-actor flag the handlers set (a class, so `@Sendable` main-actor closures can capture it).
@MainActor final class Flag {
    var count = 0
}

/// Runs `body` on a background queue and returns whether it ran off the main thread.
private func onBackgroundQueue(_ body: @escaping @Sendable () -> Void) async -> Bool {
    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
        DispatchQueue.global(qos: .utility).async {
            let offMain = !Thread.isMainThread
            body()
            continuation.resume(returning: offMain)
        }
    }
}

@MainActor @Suite struct PowerSourceOffMainTests {
    @Test func theIOKitCallbackHopsToTheMainActor() async {
        let flag = Flag()
        let callback = MainActorCallback { flag.count += 1 }
        let offMain = await onBackgroundQueue { PowerSourceNotifications.callback(callback.context) }
        #expect(offMain)
        #expect(await eventually { flag.count == 1 })
    }

    @Test func aMissingContextIsIgnored() async {
        let offMain = await onBackgroundQueue { PowerSourceNotifications.callback(nil) }
        #expect(offMain)
    }

    @Test func onTheMainThreadItRunsAtOnce() {
        let flag = Flag()
        let callback = MainActorCallback { flag.count += 1 }
        PowerSourceNotifications.callback(callback.context)                  // the main run loop's delivery
        #expect(flag.count == 1)
    }
}

@MainActor @Suite struct ThermalOffMainTests {
    @Test func aThermalChangePostedOnABackgroundThreadReachesTheSnapshotAndObservers() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.thermal = .critical
        let center = harness.platform.localCenter
        let offMain = await onBackgroundQueue {
            center.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        }
        #expect(offMain)
        #expect(await eventually { harness.monitor.snapshot.thermal == .critical })
        #expect(seen == [.thermalChanged(.critical)])
        token.cancel()
    }
}

@MainActor @Suite struct LowPowerOffMainTests {
    @Test func lowPowerModePostedOnABackgroundThreadReachesTheSnapshotAndObservers() async {
        let harness = SignalsHarness()
        await harness.start()
        var seen: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { seen.append($0) }
        harness.platform.power.isLowPowerMode = true
        let center = harness.platform.localCenter
        let offMain = await onBackgroundQueue {
            center.post(name: SignalsMonitor.lowPowerModeChanged, object: nil)
        }
        #expect(offMain)
        #expect(await eventually { harness.monitor.snapshot.power.isLowPowerMode })
        #expect(seen == [.powerChanged])
        token.cancel()
    }

    @Test func theAnyThreadBlockItselfIsNonisolated() async {
        let flag = Flag()
        let block = SignalsMonitor.hop { flag.count += 1 }
        let offMain = await onBackgroundQueue { block(Notification(name: .init("test"))) }
        #expect(offMain)
        #expect(await eventually { flag.count == 1 })
    }
}

@MainActor @Suite struct CameraListenerOffMainTests {
    @Test func theCoreMediaIOBlockHopsToTheMainActor() async {
        let flag = Flag()
        let offMain = await onBackgroundQueue {
            let block = CoreMediaIOCameras.listenerBlock { flag.count += 1 }   // built and called off the main thread
            var address = CMIOObjectPropertyAddress()
            block(0, &address)
        }
        #expect(offMain)
        #expect(await eventually { flag.count == 1 })
    }
}

@MainActor @Suite struct DistributedObserverOffMainTests {
    @Test func theSelectorTargetHopsToTheMainActor() async {
        let flag = Flag()
        let observer = DistributedObserver { flag.count += 1 }
        let offMain = await onBackgroundQueue { observer.receive(Notification(name: .init("com.apple.screenIsLocked"))) }
        #expect(offMain)
        #expect(await eventually { flag.count == 1 })
    }

    @Test func onTheMainThreadItRunsAtOnce() {
        let flag = Flag()
        DistributedObserver { flag.count += 1 }.receive(Notification(name: .init("com.apple.screenIsLocked")))
        #expect(flag.count == 1)
    }
}

@MainActor @Suite struct MainHopOffMainTests {
    @Test func offMainItHopsAndOnMainItRunsAtOnce() async {
        let flag = Flag()
        let offMain = await onBackgroundQueue { MainHop.run { flag.count += 1 } }
        #expect(offMain)
        #expect(await eventually { flag.count == 1 })
        MainHop.run { flag.count += 1 }
        #expect(flag.count == 2)
    }
}

@Suite struct WindowListOffMainTests {
    @Test func theWindowListIsReadOffTheMainThread() async {
        // Read-only and permission-free (bounds, layers, owner PIDs and alpha only).
        let snapshot = await WindowListSnapshot.read()
        #expect(snapshot.windows.allSatisfy { $0.layer == 0 || $0.layer == FullScreenDetector.menuBarLayer })
        let box = SnapshotBox()
        let offMain = await onBackgroundQueue { box.store(WindowListSnapshot.capture()) }
        #expect(offMain && box.value != nil)
    }

    @Test func theWindowServerIsRecognisedByItsExecutablePath() {
        #expect(WindowListSnapshot.isWindowServerPath("/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer"))
        #expect(!WindowListSnapshot.isWindowServerPath("/Applications/WindowServer Helper.app/Contents/MacOS/Helper"))
        #expect(!WindowListSnapshot.isWindowServer(getpid()))
    }
}

@Suite struct ProcessScanOffMainTests {
    @Test func theLibprocScanRunsOffTheMainThreadAndFindsThisProcess() async {
        let processes = await ProcessScanner.scan()
        let me = processes.first { $0.processID == getpid() }
        #expect(me != nil)
        #expect(me?.executableName == WindowListSnapshot.executablePath(of: getpid()).map { ($0 as NSString).lastPathComponent })
        let box = ProcessesBox()
        let offMain = await onBackgroundQueue { box.store(ProcessScanner.capture()) }
        #expect(offMain && box.count > 1)
    }
}

/// Lock-protected result boxes for the background closures (`@unchecked Sendable`: every access holds `lock`).
private nonisolated final class SnapshotBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: WindowListSnapshot?
    func store(_ value: WindowListSnapshot) { lock.withLock { stored = value } }
    var value: WindowListSnapshot? { lock.withLock { stored } }
}

private nonisolated final class ProcessesBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [ProcessScanner.Process] = []
    func store(_ value: [ProcessScanner.Process]) { lock.withLock { stored = value } }
    var count: Int { lock.withLock { stored.count } }
}
