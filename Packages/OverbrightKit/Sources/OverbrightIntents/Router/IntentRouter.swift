// OverbrightIntents — the router behind the app target's App Intents adapters. ARCHITECTURE.md §7.7, §10.0, D18.
// Seam placeholder (WP0a): the no-argument initializer is fixed; WP8 adds `connect(boost:displays:signals:)`,
// one method per intent and `focus(_:)`.

/// Routes the one-line intent adapters in `App/Intents/` to the engine. `OverbrightApp.init` creates it with no
/// arguments and registers it with `AppDependencyManager`, so an intent that launches the app can resolve it before
/// `applicationDidFinishLaunching`; the composition root connects it once the services exist.
@MainActor
public final class IntentRouter {
    /// Creates an unconnected router.
    public init() {}
}
