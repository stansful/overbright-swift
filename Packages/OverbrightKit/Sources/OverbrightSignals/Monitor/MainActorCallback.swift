// OverbrightSignals/Monitor/MainActorCallback.swift — the context object of a C callback. ARCHITECTURE.md §8.1 rule 2.
// Thread: any. C callbacks (IOKit power sources) carry their context through `Unmanaged`; this object holds the
// main-actor handler and hops to it through `MainHop`, so the callback is safe on any thread.
import Foundation

/// The context of a C callback (`Unmanaged.passUnretained(callback).toOpaque()`): an immutable main-actor handler.
/// Whoever registers the callback keeps this object alive until the source is removed.
nonisolated final class MainActorCallback: Sendable {
    /// What the callback does on the main actor.
    let handler: @MainActor @Sendable () -> Void

    /// A callback context for `handler`.
    init(_ handler: @escaping @MainActor @Sendable () -> Void) { self.handler = handler }

    /// Runs the handler through `MainHop` (callable from any thread).
    func fire() { MainHop.run(handler) }

    /// The object behind a C callback's context pointer.
    static func from(_ context: UnsafeMutableRawPointer) -> MainActorCallback {
        Unmanaged<MainActorCallback>.fromOpaque(context).takeUnretainedValue()
    }

    /// The context pointer to pass to a C registration (unretained: the registrant keeps `self` alive).
    var context: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
}
