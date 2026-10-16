// OverbrightSignals/Monitor/DistributedObserver.swift — distributed notifications delivered immediately.
// ARCHITECTURE.md §7.1 ("Lock / unlock", "Screensaver", "ColorSync profile change"), §8.1 rule 2.
// AppKit suspends distributed-notification delivery while an application is inactive, and the block API coalesces
// what arrives meanwhile until it becomes active again. Overbright is an agent app that is almost never active, so a
// lock or a screensaver would reach it only when the user next clicked it. The selector API with
// `suspensionBehavior: .deliverImmediately` delivers at once whatever the activation state; its observer must be an
// `NSObject`, so it lives in this nonisolated class (a main-actor `@objc` method would trap off the main thread).
// Thread: the notification arrives on the main run loop (the registering thread), where `MainHop` runs the handler at
// once; `DistributedObserverOffMainTests` calls it from a background queue, where it hops.
import Foundation
import OverbrightCore

/// The target of one distributed-notification registration.
nonisolated final class DistributedObserver: NSObject, Sendable {
    private let handler: @MainActor @Sendable () -> Void

    /// An observer that runs `handler` on the main actor.
    init(_ handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    /// The selector the center calls.
    @objc func receive(_ notification: Notification) {
        MainHop.run(handler)
    }

    /// Registers `handler` for `name` on the distributed center with immediate delivery; the token removes it.
    @MainActor static func observe(_ name: Notification.Name, center: DistributedNotificationCenter = .default(),
                                   _ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken {
        let observer = DistributedObserver(handler)
        center.addObserver(observer, selector: #selector(receive(_:)), name: name, object: nil,
                           suspensionBehavior: .deliverImmediately)
        return ObservationToken { center.removeObserver(observer, name: name, object: nil) }
    }
}
