// Controls/BoostValueProvider.swift — the control's value, read in the extension process. ARCHITECTURE.md §7.7; D25.
// The liveness gate first: WindowServer restores every display when Overbright's process dies, so "not running" is
// "off" whatever the last word said (a crash or `kill -9` leaves a stale word until the next launch reloads).
import AppKit
import WidgetKit
import OverbrightChannel

/// Reads the notify word (the snapshot when the word is not valid) and gates it on the app running.
struct BoostValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: BoostChannel.appBundleID).isEmpty
        return BoostChannel.controlValue(word: NotifyStateWord().read(), snapshot: BoostChannel.readSnapshot(),
                                         appIsRunning: isRunning)
    }
}
