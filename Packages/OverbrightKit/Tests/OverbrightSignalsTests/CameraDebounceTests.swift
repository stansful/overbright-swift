// OverbrightSignalsTests/CameraDebounceTests.swift — "a camera is in use": 1 s on / 3 s off, the transport filter, hot-plug,
// and the rule switch. ARCHITECTURE.md §7.1, §7.3, D12, DESIGN.md §11.
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct CameraDebounceTests {
    private func at(_ seconds: Double) -> MonotonicInstant {
        MonotonicInstant(sinceOrigin: .milliseconds(Int64(seconds * 1000)))
    }

    @Test func onAfterOneSecondOffAfterThree() {
        var debouncer = CameraDebouncer()
        #expect(debouncer.observe(true, at: at(10)) == at(11))
        #expect(!debouncer.resolve(at: at(10.9)) && !debouncer.published)
        #expect(debouncer.resolve(at: at(11)) && debouncer.published)
        #expect(debouncer.observe(false, at: at(20)) == at(23))
        #expect(!debouncer.resolve(at: at(22.9)) && debouncer.published)
        #expect(debouncer.resolve(at: at(23)) && !debouncer.published)
    }

    @Test func briefChangesNeverPublish() {
        var debouncer = CameraDebouncer()
        debouncer.observe(true, at: at(0))
        #expect(debouncer.observe(false, at: at(0.5)) == nil)                // an app probing the camera
        #expect(!debouncer.resolve(at: at(5)) && !debouncer.published)
        debouncer.observe(true, at: at(10))
        _ = debouncer.resolve(at: at(11))
        debouncer.observe(false, at: at(12))                                  // switching devices in a call
        #expect(debouncer.observe(true, at: at(14)) == nil)
        #expect(!debouncer.resolve(at: at(20)) && debouncer.published)
    }

    @Test func aRepeatedReadingKeepsItsStart() {
        var debouncer = CameraDebouncer()
        debouncer.observe(true, at: at(0))
        #expect(debouncer.observe(true, at: at(0.8)) == at(1))
    }

    @Test func theTransportFilterKeepsBuiltInAndUSB() {
        #expect(CameraTransport.builtIn == 0x626C_746E && CameraTransport.usb == 0x7573_6220)
        #expect(CameraTransport.counts(transport: CameraTransport.builtIn, filter: .builtInAndUSB))
        #expect(CameraTransport.counts(transport: CameraTransport.usb, filter: .builtInAndUSB))
        #expect(!CameraTransport.counts(transport: CameraTransport.virtual, filter: .builtInAndUSB))
        #expect(!CameraTransport.counts(transport: nil, filter: .builtInAndUSB))
        #expect(CameraTransport.counts(transport: CameraTransport.virtual, filter: .anyCamera))
        #expect(CameraTransport.counts(transport: nil, filter: .anyCamera))
    }

    // MARK: In the monitor

    @MainActor @Test func theSnapshotFollowsTheDebouncedCamera() async {
        let harness = SignalsHarness()
        let cameras = harness.platform.cameraDevices
        cameras.add(1, transport: CameraTransport.builtIn)
        harness.settings[FillLightSettings.autoWithCamera] = true
        await harness.start()
        #expect(harness.monitor.activeSources.contains(.camera) && cameras.activeListeners == 1)
        cameras.setRunning(1, true)
        await harness.advance(.milliseconds(900))
        #expect(!harness.monitor.snapshot.isCameraInUse)
        await harness.advance(.milliseconds(100))
        #expect(harness.monitor.snapshot.isCameraInUse)
        cameras.setRunning(1, false)
        await harness.advance(.seconds(2))
        #expect(harness.monitor.snapshot.isCameraInUse)
        await harness.advance(.seconds(1))
        #expect(!harness.monitor.snapshot.isCameraInUse)
        #expect(harness.time.sleeperCount == 0)                               // nothing waits once it settled
    }

    @MainActor @Test func virtualCamerasCountOnlyForAnyCamera() async {
        let harness = SignalsHarness()
        let cameras = harness.platform.cameraDevices
        cameras.add(1, transport: CameraTransport.builtIn)
        cameras.add(2, transport: CameraTransport.virtual, running: true)
        harness.settings[FillLightSettings.autoWithCamera] = true
        harness.settings[FillLightSettings.cameraFilter] = .builtInAndUSB
        await harness.start()
        await harness.advance(.seconds(2))
        #expect(!harness.monitor.snapshot.isCameraInUse)
        harness.settings[FillLightSettings.cameraFilter] = .anyCamera
        await harness.settle()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.isCameraInUse)
    }

    @MainActor @Test func aPluggedInCameraIsListenedTo() async {
        let harness = SignalsHarness()
        let cameras = harness.platform.cameraDevices
        harness.settings[FillLightSettings.autoWithCamera] = true
        await harness.start()
        #expect(cameras.registrations == [[]])
        cameras.add(7, transport: CameraTransport.usb)                        // the device-list listener fires
        #expect(cameras.registrations == [[], [7]] && cameras.activeListeners == 1)
        cameras.setRunning(7, true)
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.isCameraInUse)
    }

    @MainActor @Test func turningTheRuleOffStopsListeningAndClearsTheValue() async {
        let harness = SignalsHarness()
        let cameras = harness.platform.cameraDevices
        cameras.add(1, transport: CameraTransport.builtIn, running: true)
        harness.settings[FillLightSettings.autoWithCamera] = true
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.isCameraInUse)
        harness.settings[FillLightSettings.autoWithCamera] = false
        await harness.settle()
        #expect(!harness.monitor.activeSources.contains(.camera))
        #expect(cameras.activeListeners == 0 && !harness.monitor.snapshot.isCameraInUse)
    }

    @MainActor @Test func theRuleOffMeansNoCameraWork() async {
        let harness = SignalsHarness()
        harness.platform.cameraDevices.add(1, transport: CameraTransport.builtIn, running: true)
        await harness.start()
        #expect(harness.platform.cameraDevices.registrations.isEmpty)
        #expect(!harness.monitor.activeSources.contains(.camera) && !harness.monitor.snapshot.isCameraInUse)
    }
}
