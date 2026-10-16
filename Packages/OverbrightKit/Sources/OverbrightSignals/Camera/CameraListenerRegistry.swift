// OverbrightSignals/Camera/CameraListenerRegistry.swift — the CoreMediaIO listener proc and the handlers it reaches.
// ARCHITECTURE.md §7.1 ("Camera in use"), §8.1 rule 2, D12, D22.
// A listener's client data is a NUMBER registered here, never an object pointer: CoreMediaIO calls the proc on its own
// notification thread, so a call already in flight when the listener is removed must find nothing instead of a freed
// object. Removal matches the proc and the client data by value, and both stay the same from add to remove (the
// `CMIOObjectPropertyListenerBlock` variant cannot do that from Swift: see `CoreMediaIOCameras`).
// Thread: any. The proc is a nonisolated C function; it looks its handler up under the lock and hops through `MainHop`
// (`CameraListenerOffMainTests` calls it from a background queue).
import CoreMediaIO
import Foundation

/// Live camera-listener handlers by number. `@unchecked Sendable`: `handlers` and `lastID` are only touched under
/// `lock`.
nonisolated final class CameraListenerRegistry: @unchecked Sendable {
    /// The registry the live cameras use.
    static let shared = CameraListenerRegistry()

    /// CoreMediaIO's listener proc for every camera listener: runs the handler registered under its client data.
    static let proc: CMIOObjectPropertyListenerProc = { _, _, _, clientData in
        CameraListenerRegistry.shared.fire(UInt(bitPattern: clientData))
        return noErr
    }

    private let lock = NSLock()
    private var handlers: [UInt: @MainActor @Sendable () -> Void] = [:]
    private var lastID: UInt = 0

    private init() {}

    /// Registers `handler`; the number (never 0, so it is never a null pointer) is the listener's client data.
    func add(_ handler: @escaping @MainActor @Sendable () -> Void) -> UInt {
        lock.withLock {
            lastID += 1
            handlers[lastID] = handler
            return lastID
        }
    }

    /// Unregisters `id`; a proc call for it that is still in flight then does nothing.
    func remove(_ id: UInt) {
        _ = lock.withLock { handlers.removeValue(forKey: id) }
    }

    /// Runs the handler of `id` on the main actor, if it is still registered.
    func fire(_ id: UInt) {
        guard let handler = lock.withLock({ handlers[id] }) else { return }
        MainHop.run(handler)
    }

    /// Whether `id` is registered now.
    func contains(_ id: UInt) -> Bool { lock.withLock { handlers[id] != nil } }

    /// The client-data pointer for `id`.
    static func clientData(_ id: UInt) -> UnsafeMutableRawPointer? { UnsafeMutableRawPointer(bitPattern: id) }
}
