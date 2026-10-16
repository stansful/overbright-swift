// OverbrightSignalsTests/Fakes/FakeCameraDevices.swift — scripted camera devices (no CoreMediaIO in tests).
import OverbrightCore
@testable import OverbrightSignals

@MainActor final class FakeCameraDevices: CameraDevices {
    struct Device {
        var running: Bool?
        var transport: UInt32?
    }

    private(set) var order: [UInt32] = []
    private var devices: [UInt32: Device] = [:]
    /// Listener sets registered and not yet cancelled.
    private(set) var activeListeners = 0
    /// Every `observe` call (a device-list change re-registers).
    private(set) var registrations: [[UInt32]] = []
    private var onChange: (@MainActor @Sendable () -> Void)?

    func deviceIDs() -> [UInt32] { order }
    func isRunningSomewhere(_ device: UInt32) -> Bool? { devices[device]?.running ?? nil }
    func transportType(_ device: UInt32) -> UInt32? { devices[device]?.transport ?? nil }

    func observe(devices: [UInt32], onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken {
        activeListeners += 1
        registrations.append(devices)
        self.onChange = onChange
        return ObservationToken { [weak self] in self?.activeListeners -= 1 }
    }

    /// Plugs in a device (the device-list listener fires).
    func add(_ id: UInt32, transport: UInt32?, running: Bool = false) {
        order.append(id)
        devices[id] = Device(running: running, transport: transport)
        onChange?()
    }

    /// A process starts or stops a stream on `id` (its listener fires).
    func setRunning(_ id: UInt32, _ running: Bool) {
        devices[id]?.running = running
        onChange?()
    }
}
