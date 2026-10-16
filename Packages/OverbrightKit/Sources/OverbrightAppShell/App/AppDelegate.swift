// OverbrightAppShell — the application delegate. ARCHITECTURE.md §7.4, §7.6, §10.0 (shared shell file, WP0a).
// Placeholder: the launch order of §7.4 (diagnostics and rescue modes, settings upgrade, status item, lifecycle
// start with Boost last) lands with the composition root.
import AppKit
import OverbrightIntents

/// The app's delegate, installed by `OverbrightApp` through `@NSApplicationDelegateAdaptor`.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The App Intents router that `OverbrightApp.init` created and registered with `AppDependencyManager` before
    /// launch (§7.7). The composition root connects it once the services exist.
    public static var intentRouter: IntentRouter?

    /// Called by `@NSApplicationDelegateAdaptor`.
    override public init() {
        super.init()
    }
}
