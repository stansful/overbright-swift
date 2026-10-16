// OverbrightSignals/Camera/CameraDevices.swift — the camera devices `CameraMonitor` reads. ARCHITECTURE.md §7.1, D21.
// Thread: main. The live implementation is `CoreMediaIOCameras`; tests use a fake, so no test touches CoreMediaIO.
import OverbrightCore

/// Camera devices and their "running somewhere" state.
@MainActor protocol CameraDevices: AnyObject {
    /// Every camera device now.
    func deviceIDs() -> [UInt32]
    /// `kCMIODevicePropertyDeviceIsRunningSomewhere`: some process runs a stream on it; nil when unreadable.
    func isRunningSomewhere(_ device: UInt32) -> Bool?
    /// `kCMIODevicePropertyTransportType`; nil when unreadable.
    func transportType(_ device: UInt32) -> UInt32?
    /// Listens for "running somewhere" on `devices` and for changes of the device list itself (hot-plug); `onChange`
    /// runs on the main actor. Cancelling the token removes every listener.
    func observe(devices: [UInt32], onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken
}
