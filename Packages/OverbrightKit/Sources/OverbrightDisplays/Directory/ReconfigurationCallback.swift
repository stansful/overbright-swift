// OverbrightDisplays/Directory/ReconfigurationCallback.swift — the C entry point of
// `CGDisplayRegisterReconfigurationCallback`. ARCHITECTURE.md §7.1 (entry point: a `nonisolated static` C function,
// context through `Unmanaged`, then `DispatchQueue.main.async`), §8.1 rule 2, §10.4.
// Thread: the callback may arrive on any thread; it never touches main-actor state there. It only hops to the main
// queue, where `MainActor.assumeIsolated` is valid, and hands the flags to the receiver (test
// `ReconfigurationCallbackOffMainTests` calls it from a background queue).
import CoreGraphics
import Foundation

/// Receives reconfiguration callbacks on the main actor.
protocol ReconfigurationReceiver: AnyObject {
    /// One callback for `display` with `flags`.
    func reconfigured(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags)
}

/// The registration's context: a weak reference to the receiver, so a callback that arrives after the receiver is
/// gone does nothing. Main-actor isolated (and therefore `Sendable`); the C function only passes it to the main queue.
final class ReconfigurationContext {
    /// The receiver; nil once it is released.
    weak var receiver: (any ReconfigurationReceiver)?
    /// A context for `receiver`.
    init(receiver: any ReconfigurationReceiver) { self.receiver = receiver }
}

/// The reconfiguration callback and its registration.
nonisolated enum ReconfigurationCallback {
    /// The one C function registered (the same pointer must be passed to remove it again).
    static let function: CGDisplayReconfigurationCallBack = { display, flags, info in
        ReconfigurationCallback.deliver(display: display, flags: flags, info: info)
    }

    /// Hops to the main queue and hands the callback to the context's receiver. Safe on any thread.
    static func deliver(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, info: UnsafeMutableRawPointer?) {
        guard let info else { return }
        let context = Unmanaged<ReconfigurationContext>.fromOpaque(info).takeUnretainedValue()
        DispatchQueue.main.async {
            // On the main queue, so the main actor's executor is the current one.
            MainActor.assumeIsolated { context.receiver?.reconfigured(display: display, flags: flags) }
        }
    }

    /// Registers `function` with `context` (retained until `unregister`). False when CoreGraphics refuses.
    @MainActor static func register(_ context: ReconfigurationContext) -> Bool {
        let info = Unmanaged.passRetained(context)
        guard CGDisplayRegisterReconfigurationCallback(function, info.toOpaque()) == .success else {
            info.release()
            return false
        }
        return true
    }

    /// Removes the registration made by `register(_:)` and releases its context.
    @MainActor static func unregister(_ context: ReconfigurationContext) {
        let info = Unmanaged.passUnretained(context)
        CGDisplayRemoveReconfigurationCallback(function, info.toOpaque())
        info.release()
    }
}
