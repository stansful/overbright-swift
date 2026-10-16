// OverbrightSignals/Apps/RunningAppInfo+Workspace.swift — `RunningAppInfo` from AppKit's running application.
// ARCHITECTURE.md §7.2, §7.3. Thread: any (`NSRunningApplication` is thread-safe: its properties are returned atomically).
import AppKit

extension RunningAppInfo {
    /// The facts of a running application (its name only for the UI).
    nonisolated init(_ app: NSRunningApplication) {
        self.init(bundleID: app.bundleIdentifier, processID: app.processIdentifier,
                  executableName: app.executableURL?.lastPathComponent, bundleURL: app.bundleURL,
                  localizedName: app.localizedName ?? app.executableURL?.lastPathComponent ?? "",
                  isRegular: app.activationPolicy == .regular)
    }
}
