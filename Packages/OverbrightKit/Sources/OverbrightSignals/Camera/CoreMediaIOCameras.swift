// OverbrightSignals/Camera/CoreMediaIOCameras.swift — "is a camera in use?" without opening one. ARCHITECTURE.md §7.1
// ("Camera in use"), §7.3, §8.1 rule 2, D12, D22.
// CoreMediaIO, public since macOS 10.7: enumerate `kCMIOHardwarePropertyDevices` on the system object, read
// `kCMIODevicePropertyDeviceIsRunningSomewhere` per device, and listen for changes per device plus once on the system
// object for hot-plug. No stream or capture session is ever opened, so no camera permission is expected [HW: H-F1; if a
// prompt appears the rule becomes manual].
// Listeners use `CMIOObjectAddPropertyListener` (a C proc and client data), not the block variant §7.1 names: Swift
// imports `CMIOObjectPropertyListenerBlock` as a native closure and wraps the value in a NEW block at every call (even a
// `@convention(block)` value: verified in SIL at -Onone and -O), so `CMIOObjectRemovePropertyListenerBlock` could never
// name the block that Add copied, and the listeners would outlive the camera rule (D22). The proc and its client data
// (a number in `CameraListenerRegistry`) are plain values, identical in Add and Remove.
// Thread: main for the reads and the registration. CoreMediaIO calls the proc on its notification thread; the proc is a
// nonisolated C function that hops through `MainHop` (`CameraListenerOffMainTests`).
import CoreMediaIO
import OverbrightCore
import os

private let log = Log.logger(.signals)

/// The live camera devices.
final class CoreMediaIOCameras: CameraDevices {
    /// One listener registration call, `CMIOObjectAddPropertyListener` or `CMIOObjectRemovePropertyListener` (a test
    /// records them instead).
    typealias ListenerCall = (CMIOObjectID, CMIOObjectPropertyAddress, CMIOObjectPropertyListenerProc,
                              UnsafeMutableRawPointer?) -> OSStatus

    private let addListener: ListenerCall
    private let removeListener: ListenerCall

    /// The live cameras; touches nothing until a method is called.
    convenience init() {
        self.init(add: Self.addPropertyListener, remove: Self.removePropertyListener)
    }

    /// Cameras whose listener registrations go through `add` and `remove` (tests record them).
    init(add: @escaping ListenerCall, remove: @escaping ListenerCall) {
        addListener = add; removeListener = remove
    }

    /// Every CoreMediaIO device.
    func deviceIDs() -> [UInt32] {
        var address = Self.address(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(used) / MemoryLayout<CMIOObjectID>.size))
    }

    /// `kCMIODevicePropertyDeviceIsRunningSomewhere`.
    func isRunningSomewhere(_ device: UInt32) -> Bool? {
        uint32(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere), of: device).map { $0 != 0 }
    }

    /// `kCMIODevicePropertyTransportType`.
    func transportType(_ device: UInt32) -> UInt32? {
        uint32(CMIOObjectPropertySelector(kCMIODevicePropertyTransportType), of: device)
    }

    /// Listeners on every device's running state and on the device list; `onChange` runs on the main actor. The token
    /// removes each listener with the same proc and client data it was added with, then unregisters the handler.
    func observe(devices: [UInt32], onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken {
        let registry = CameraListenerRegistry.shared
        let id = registry.add(onChange)
        let clientData = CameraListenerRegistry.clientData(id)
        let proc = CameraListenerRegistry.proc
        var registered: [(object: CMIOObjectID, address: CMIOObjectPropertyAddress)] = []
        let running = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        let listed = CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices)
        let targets = devices.map { ($0, running) } + [(CMIOObjectID(kCMIOObjectSystemObject), listed)]
        for (object, selector) in targets {
            let address = Self.address(selector)
            if addListener(object, address, proc, clientData) == noErr { registered.append((object, address)) }
        }
        return ObservationToken { [removeListener] in
            for (object, address) in registered {
                let status = removeListener(object, address, proc, clientData)
                if status != noErr { log.error("camera listener removal failed: \(status, privacy: .public)") }
            }
            registry.remove(id)
        }
    }

    // MARK: Private

    private static func addPropertyListener(_ object: CMIOObjectID, _ address: CMIOObjectPropertyAddress,
                                            _ proc: CMIOObjectPropertyListenerProc,
                                            _ clientData: UnsafeMutableRawPointer?) -> OSStatus {
        var address = address
        return CMIOObjectAddPropertyListener(object, &address, proc, clientData)
    }

    private static func removePropertyListener(_ object: CMIOObjectID, _ address: CMIOObjectPropertyAddress,
                                               _ proc: CMIOObjectPropertyListenerProc,
                                               _ clientData: UnsafeMutableRawPointer?) -> OSStatus {
        var address = address
        return CMIOObjectRemovePropertyListener(object, &address, proc, clientData)
    }

    private static func address(_ selector: CMIOObjectPropertySelector) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(mSelector: selector,
                                  mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                  mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    }

    private func uint32(_ selector: CMIOObjectPropertySelector, of object: CMIOObjectID) -> UInt32? {
        var address = Self.address(selector)
        guard CMIOObjectHasProperty(object, &address) else { return nil }
        var value: UInt32 = 0
        var used: UInt32 = 0
        let status = CMIOObjectGetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &value)
        return status == noErr ? value : nil
    }
}
