// App/Intents/OverbrightFocusFilter.swift — "Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// The Focus filter (placeholder without parameters; WP8 adds Leave Alone / Off / On at a level and the launch-time
/// read of `current`).
struct OverbrightFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Overbright"

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "Overbright") }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        router.focus(.leaveAlone)
        return .result()
    }
}
