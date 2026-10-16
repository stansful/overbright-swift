// OverbrightSignals/Monitor/RunningAppsObserver.swift — key-value observing of the running-application list.
// ARCHITECTURE.md §7.1 ("Active Space, app activation, launch, termination"), §7.2, §8.1 rule 2.
// On macOS 27.0.1 the workspace posts no did-launch or did-terminate notification for an `LSUIElement` app, and only
// will-launch for an app that switches to the accessory policy before it finishes launching [VERIFIED, WP14 probe]:
// most menu-bar boosters and gamma writers. KVO on `NSWorkspace.runningApplications` (`.old` and `.new`) reports every
// one of them, so Signals observes both and posts each launch and termination once (`SignalsMonitor.appsChanged`).
// Thread: AppKit changes the list on the main run loop, so the change handler runs there and `MainHop` calls the
// handler at once. The handler is built in a nonisolated function (under this module's default MainActor isolation a
// closure written in a main-actor method would trap on another thread); `RunningAppsObserverOffMainTests` calls it from
// a background queue.
import AppKit
import OverbrightCore

/// The apps that joined and left the running list in one change.
nonisolated struct RunningAppsChange: Hashable, Sendable {
    /// Apps that joined.
    var added: [RunningAppInfo]
    /// Apps that left.
    var removed: [RunningAppInfo]

    /// Nobody joined or left.
    var isEmpty: Bool { added.isEmpty && removed.isEmpty }

    /// The change one KVO notification describes: an insertion carries the new apps, a removal the old ones; a
    /// replacement (the same process may be on both sides) and a setting (the whole list) are compared by process ID.
    static func make(kind: NSKeyValueChange, old: [RunningAppInfo]?, new: [RunningAppInfo]?) -> RunningAppsChange {
        switch kind {
        case .insertion:
            RunningAppsChange(added: new ?? [], removed: [])
        case .removal:
            RunningAppsChange(added: [], removed: old ?? [])
        case .replacement, .setting:
            difference(old: old ?? [], new: new ?? [])
        @unknown default:
            difference(old: old ?? [], new: new ?? [])
        }
    }

    /// The apps only in `new` and the apps only in `old`, by process ID.
    static func difference(old: [RunningAppInfo], new: [RunningAppInfo]) -> RunningAppsChange {
        let oldPIDs = Set(old.map(\.processID)), newPIDs = Set(new.map(\.processID))
        return RunningAppsChange(added: new.filter { !oldPIDs.contains($0.processID) },
                                 removed: old.filter { !newPIDs.contains($0.processID) })
    }
}

/// Observes a list of running applications by KVO.
nonisolated enum RunningAppsObserver {
    /// Observes `keyPath` of `object` (`NSWorkspace.shared`, `\.runningApplications` in the live platform) with the
    /// old and new values; `handler` gets every non-empty change on the main actor. The token ends the observation.
    @MainActor static func observe<Object: NSObject>(_ object: Object, _ keyPath: KeyPath<Object, [NSRunningApplication]>,
                                                     _ handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void)
        -> ObservationToken {
        let observation = object.observe(keyPath, options: [.old, .new], changeHandler: changeHandler(handler))
        return ObservationToken { observation.invalidate() }
    }

    /// The KVO change handler: converts on the posting thread (`NSRunningApplication` is thread-safe), then hops.
    static func changeHandler<Object>(_ handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void)
        -> @Sendable (Object, NSKeyValueObservedChange<[NSRunningApplication]>) -> Void {
        { _, change in
            deliver(kind: change.kind, old: change.oldValue, new: change.newValue, to: handler)
        }
    }

    /// Builds the change and runs `handler` with it through `MainHop` (nothing for an empty change).
    static func deliver(kind: NSKeyValueChange, old: [NSRunningApplication]?, new: [NSRunningApplication]?,
                        to handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void) {
        let apps = RunningAppsChange.make(kind: kind, old: old?.map(RunningAppInfo.init), new: new?.map(RunningAppInfo.init))
        guard !apps.isEmpty else { return }
        MainHop.run { handler(apps) }
    }
}
