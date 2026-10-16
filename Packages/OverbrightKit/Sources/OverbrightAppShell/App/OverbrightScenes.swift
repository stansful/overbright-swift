// OverbrightAppShell — the SwiftUI scenes of the app. ARCHITECTURE.md §7.6, §10.0 (shared shell file, WP0a), D13.
// The menu bar item is an AppKit `NSStatusItem` and every window is AppKit-owned, so the only scene is an empty
// `Settings` scene that keeps the system's Edit menu; ⌘, is routed to our own Settings window once it exists.
import SwiftUI

/// The scenes `OverbrightApp.body` returns.
public struct OverbrightScenes: Scene {
    private let appDelegate: AppDelegate

    /// - Parameter appDelegate: the delegate SwiftUI created for `@NSApplicationDelegateAdaptor`.
    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    /// An empty `Settings` scene: no window opens at launch.
    public var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
