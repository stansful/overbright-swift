// OverbrightDesign/Styles/KeyboardInteraction.swift — whether the user is working with the keyboard. DESIGN.md §5.12:
// focus rings show only after keyboard interaction. A key press (Tab, arrows, Space) turns it on, a click turns it
// off; the local monitor sees only Overbright's own events and does nothing while no event arrives.
import AppKit
import Observation

/// The app-wide "last interaction was the keyboard" flag behind `.overbrightFocusRing`.
@MainActor @Observable public final class KeyboardInteraction {
    /// The one flag for every surface.
    public static let shared = KeyboardInteraction()

    /// The last key or mouse event was a key press.
    public private(set) var isActive = false
    @ObservationIgnored private var monitor: Any?

    /// A flag that starts inactive.
    public init() {}

    /// Starts following the app's key and mouse events (once; later calls do nothing).
    public func startObserving() {
        guard monitor == nil else { return }
        // Local monitors run on the main thread, inside the app's event dispatch.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] event in
            self?.record(isKey: event.type == .keyDown)
            return event
        }
    }

    /// Records a key press (`true`) or a click (`false`).
    public func record(isKey: Bool) {
        if isActive != isKey { isActive = isKey }
    }
}
