// OverbrightAppShell/App/ServiceStack.swift — the services with a lifecycle, by role, and their one order.
// ARCHITECTURE.md §7.4 (launch and quit), §10.15 (Displays → Triggers → Signals → FillLight → HotKeys → Updates →
// Intents → Boost last; stop in reverse, Boost first), D7, D23. A role is empty when the wiring has no service with a
// lifecycle for it (the simulated ports are plain fakes); the order of the rest never changes.
import OverbrightCore

/// The services of one launch that start and stop, by role.
struct ServiceStack {
    /// The display directory (the reconfiguration callback and the screen-parameters observer).
    var displays: (any ServiceLifecycle)?
    /// The trigger windows (removes every one when it stops).
    var triggers: (any ServiceLifecycle)?
    /// System state and events.
    var signals: (any ServiceLifecycle)?
    /// The Fill Light.
    var fillLight: (any ServiceLifecycle)?
    /// Global shortcuts.
    var hotKeys: (any ServiceLifecycle)?
    /// The update check.
    var updates: (any ServiceLifecycle)?
    /// The control's state publish point (the router itself is connected before the launch work, §7.4).
    var intents: (any ServiceLifecycle)?
    /// The engine: starts last, stops first.
    var boost: (any ServiceLifecycle)?

    /// The roles in start order.
    enum Role: String, CaseIterable {
        case displays, triggers, signals, fillLight, hotKeys, updates, intents, boost
    }

    /// The service in `role`, if any.
    func service(_ role: Role) -> (any ServiceLifecycle)? {
        switch role {
        case .displays: displays
        case .triggers: triggers
        case .signals: signals
        case .fillLight: fillLight
        case .hotKeys: hotKeys
        case .updates: updates
        case .intents: intents
        case .boost: boost
        }
    }

    /// Start order: every role in `Role.allCases` order, Boost last.
    var startOrder: [any ServiceLifecycle] { Role.allCases.compactMap(service) }

    /// Stop order: the reverse, Boost first.
    var stopOrder: [any ServiceLifecycle] { startOrder.reversed() }
}
