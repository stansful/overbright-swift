// OverbrightSignals/Power/PowerSourceNotifications.swift — IOKit power-source run-loop sources. ARCHITECTURE.md §7.1
// ("Adapter ↔ battery": always on; "Battery percent": boost-only, on battery), §8.1 rule 2, D22.
// Thread: the C callback is a nonisolated static function; IOKit calls it on the run loop the source was added to (the
// main run loop, so `MainHop` runs the handler at once), and `PowerSourceOffMainTests` calls it from a background queue
// (then it hops). Its context is a `MainActorCallback` passed unretained; the returned token keeps it alive and removes
// the source.
// - `IOPSCreateLimitedPowerNotification` fires only when the providing source switches (AC, battery, UPS): cheap, so it
//   runs whenever Signals runs.
// - `IOPSNotificationCreateRunLoopSource` fires on every power-source change, percentage updates included: it runs only
//   while the boost is active on battery.
import CoreFoundation
import IOKit.ps
import OverbrightCore

/// Registers the two IOKit power-source notifications on the main run loop.
nonisolated enum PowerSourceNotifications {
    /// The IOKit callback. Nonisolated on purpose: a closure literal written in a main-actor context would be
    /// inferred `@MainActor` and trap when called off the main thread.
    static let callback: IOPowerSourceCallbackType = { context in
        guard let context else { return }
        MainActorCallback.from(context).fire()
    }

    /// Source switches (adapter ↔ battery ↔ UPS). Nil when IOKit refuses.
    @MainActor static func observeSourceSwitches(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        add(handler) { IOPSCreateLimitedPowerNotification(callback, $0) }
    }

    /// Every power-source change (percent updates included). Nil when IOKit refuses.
    @MainActor static func observeEveryChange(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        add(handler) { IOPSNotificationCreateRunLoopSource(callback, $0) }
    }

    /// Adds the source made by `make` to the main run loop (common modes, so it fires while a menu tracks too).
    @MainActor private static func add(_ handler: @escaping @MainActor @Sendable () -> Void,
                                       make: (UnsafeMutableRawPointer) -> Unmanaged<CFRunLoopSource>?) -> ObservationToken? {
        let box = MainActorCallback(handler)
        guard let source = make(box.context)?.takeRetainedValue() else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return ObservationToken {
            withExtendedLifetime(box) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                CFRunLoopSourceInvalidate(source)
            }
        }
    }
}
