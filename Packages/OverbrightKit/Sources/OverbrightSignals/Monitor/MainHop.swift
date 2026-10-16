// OverbrightSignals/Monitor/MainHop.swift — the one way a system callback reaches the main actor. ARCHITECTURE.md §8.1
// rule 2 (every entry point the system may call off the main thread is explicitly nonisolated), §7.1.
// Thread: any. Under this module's default MainActor isolation an un-annotated closure or `@objc` method is main-actor
// isolated and TRAPS when the system calls it from another thread, before any hop inside it could run. So every C
// callback, CoreMediaIO block and any-thread notification block in Signals is a nonisolated function or a `@Sendable`
// closure that calls `MainHop.run`: on the main thread it runs the body at once (the run-loop sources and `queue: .main`
// observers deliver there, so events stay synchronous); on any other thread it hops with a main-actor task.
import Foundation

/// Runs main-actor work from a callback on any thread.
nonisolated enum MainHop {
    /// Runs `body` now when called on the main thread, else on the main actor as soon as it is free.
    static func run(_ body: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }          // on the main thread: the main actor's executor
        } else {
            Task { @MainActor in body() }
        }
    }
}
