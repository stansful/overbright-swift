// Shared/BoostControlIntent.swift — the dormant control's action, a member of both the app target and the
// OverbrightControls extension (one synchronized folder in both targets). ARCHITECTURE.md §7.7, D18, D25.
// Placeholder written by WP0a so that both targets compile; its owner (WP8) implements it: in the app process it
// forwards to the router, in the extension process it hands the request to the app through the overbright:// route.
import AppIntents

/// Turns extra brightness on or off from the Control Center control. The same type name in both bundles gives the
/// same intent identifier in both metadata sets.
@available(macOS 26.0, *)
struct BoostControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Extra Brightness"
    /// The Shortcuts-facing intents live in App/Intents; this one only serves the control.
    static let isDiscoverable = false

    /// On or off.
    @Parameter(title: "Extra Brightness")
    var value: Bool

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
