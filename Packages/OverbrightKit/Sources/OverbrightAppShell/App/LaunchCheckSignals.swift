// OverbrightAppShell/App/LaunchCheckSignals.swift — the signals the launch check and `--restore-gamma` read.
// ARCHITECTURE.md §7.4 (launch check step 1: skip while the session is not on the console), D27.
//
// The launch check runs before any service starts, so the real `SignalsMonitor` has not read the console state yet
// (its snapshot holds a default). Until the monitor has started, this view reads `kCGSessionOnConsoleKey` itself
// (read-only, `CGSessionCopyCurrentDictionary`); afterwards it is the monitor's snapshot unchanged. Events, the boost
// sources and the Focus sink go straight to the monitor, so the deferred check still runs on `sessionBecameActive`.
import CoreGraphics
import Observation
import OverbrightCore

/// The monitor's signals, with the console state read live until the monitor has started.
@Observable final class LaunchCheckSignals: SystemSignals {
    @ObservationIgnored private let base: any SystemSignals
    @ObservationIgnored private let hasStarted: @MainActor () -> Bool
    @ObservationIgnored private let isOnConsole: @MainActor () -> Bool

    /// A view of `base` that reads the console through `isOnConsole` while `hasStarted` is false.
    init(base: any SystemSignals, hasStarted: @escaping @MainActor () -> Bool,
         isOnConsole: @escaping @MainActor () -> Bool = LaunchCheckSignals.sessionIsOnConsole) {
        self.base = base; self.hasStarted = hasStarted; self.isOnConsole = isOnConsole
    }

    /// The monitor's snapshot; before it started, with the console state read now.
    var snapshot: SystemSnapshot {
        var snapshot = base.snapshot
        if !hasStarted() { snapshot.isSessionActive = isOnConsole() }
        return snapshot
    }

    func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        base.addEventObserver(handler)
    }
    func setBoostActive(_ active: Bool) { base.setBoostActive(active) }
    func refreshPowerNow() { base.refreshPowerNow() }
    func setFocusDirective(_ directive: FocusDirective) { base.setFocusDirective(directive) }

    /// `CGSessionCopyCurrentDictionary()[kCGSessionOnConsoleKey]`; true when the dictionary or the key is missing
    /// (the check then runs, as it would without this read).
    static func sessionIsOnConsole() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        return session[kCGSessionOnConsoleKey as String] as? Bool ?? true
    }
}
