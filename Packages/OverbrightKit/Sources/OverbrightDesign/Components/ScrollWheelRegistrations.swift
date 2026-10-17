// OverbrightDesign/Components/ScrollWheelRegistrations.swift — where `ScrollWheelSteps` installs its local event
// monitor and its window observers. DESIGN.md §5.5, §15 (no work while the pointer is elsewhere). Each one is counted
// while installed, so a test can see that a listener which goes away while it listens takes all of its own down
// (ScrollWheelStepsTests).
import AppKit

/// Installs and removes the scroll listeners' event monitor and window observers, and counts what is installed. The
/// app's listeners share `system`; a test gives a listener its own and checks that it drops to zero.
@MainActor final class ScrollWheelRegistrations {
    /// The registrations of the app's listeners.
    static let system = ScrollWheelRegistrations()

    /// Local scroll-wheel monitors installed and not yet removed.
    private(set) var monitors = 0
    /// Window observers added and not yet removed.
    private(set) var observers = 0

    /// A local scroll-wheel monitor running `handler` (it runs on the main thread, inside the app's event dispatch).
    func addMonitor(_ handler: @escaping (NSEvent) -> NSEvent?) -> Any? {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: handler)
        if monitor != nil { monitors += 1 }
        return monitor
    }

    /// Removes a monitor from `addMonitor(_:)`.
    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
        monitors -= 1
    }

    /// Observes `name` from `window` on the main queue.
    func observe(_ name: Notification.Name, of window: NSWindow,
                 _ block: @escaping @Sendable (Notification) -> Void) -> any NSObjectProtocol {
        observers += 1
        return NotificationCenter.default.addObserver(forName: name, object: window, queue: .main, using: block)
    }

    /// Removes an observer from `observe(_:of:_:)`.
    func removeObserver(_ observer: any NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
        observers -= 1
    }
}
