// OverbrightSignals/Camera/CoreMediaIOCameras.swift — "is a camera in use?" without opening one. ARCHITECTURE.md §7.1
// ("Camera in use"), §7.3, §8.1 rule 2, D12.
// CoreMediaIO, public since macOS 10.7: enumerate `kCMIOHardwarePropertyDevices` on the system object, read
// `kCMIODevicePropertyDeviceIsRunningSomewhere` per device, and listen for changes with
// `CMIOObjectAddPropertyListenerBlock` per device plus one on the system object for hot-plug. No stream or capture
// session is ever opened, so no camera permission is expected [HW: H-F1; if a prompt appears the rule becomes manual].
// Thread: main for the reads. The listener block is built in a nonisolated function (a closure written in a main-actor
// context would be inferred `@MainActor` and trap off the main queue); CoreMediaIO calls it on the queue we pass, the
// main queue, and `MainHop` runs the handler there at once; `CameraListenerOffMainTests` calls it from a background
// queue, where it hops instead.
import CoreMediaIO
import Dispatch
import OverbrightCore

/// The live camera devices.
final class CoreMediaIOCameras: CameraDevices {
    /// Touches nothing until a method is called.
    init() {}

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

    /// Listeners on every device's running state and on the device list, delivered on the main queue.
    func observe(devices: [UInt32], onChange: @escaping @MainActor @Sendable () -> Void) -> ObservationToken {
        let block = Self.listenerBlock(onChange)
        var registered: [(object: CMIOObjectID, address: CMIOObjectPropertyAddress)] = []
        let running = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        let listed = CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices)
        let targets = devices.map { ($0, running) } + [(CMIOObjectID(kCMIOObjectSystemObject), listed)]
        for (object, selector) in targets {
            var address = Self.address(selector)
            if CMIOObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block) == noErr {
                registered.append((object, address))
            }
        }
        return ObservationToken {
            for (object, address) in registered {
                var address = address
                _ = CMIOObjectRemovePropertyListenerBlock(object, &address, DispatchQueue.main, block)
            }
        }
    }

    /// The listener block: nonisolated, hops through `MainHop`.
    nonisolated static func listenerBlock(_ onChange: @escaping @MainActor @Sendable () -> Void)
        -> CMIOObjectPropertyListenerBlock {
        { _, _ in MainHop.run(onChange) }
    }

    // MARK: Private

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
