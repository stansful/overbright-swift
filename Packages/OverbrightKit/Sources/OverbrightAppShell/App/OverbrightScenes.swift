// OverbrightAppShell/App/OverbrightScenes.swift — the SwiftUI scenes of the app. ARCHITECTURE.md §7.6, §10.0 (shared
// shell file, contract owner); D13. The menu bar item is an AppKit `NSStatusItem` and every window is AppKit-owned,
// so the only scene is an empty `Settings` scene: it opens no window at launch and keeps the system's Edit menu;
// its "Settings…" command (⌘,) is replaced by one that opens Overbright's own Settings window. WP0b verifies the shape
// (no window at launch, ⌘, routed, the app survives closing Settings).
import SwiftUI

/// The scenes `OverbrightApp.body` returns.
public struct OverbrightScenes: Scene {
    private let appDelegate: AppDelegate

    /// - Parameter appDelegate: the delegate SwiftUI created for `@NSApplicationDelegateAdaptor`.
    public init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    /// An empty `Settings` scene whose ⌘, opens our window.
    public var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "Settings…", bundle: .module,
                              comment: "Menu: the app menu item that opens the Settings window")) { [appDelegate] in
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",")
            }
        }
    }
}
