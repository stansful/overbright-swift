// App/Intents/TurnOnOverbrightIntent.swift — "Turn On Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightIntents

/// Turn On Overbright.
struct TurnOnOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Overbright"
    static let description = IntentDescription("Turns Overbright on. Each display uses its own level.")

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.turnOn()
        return .result()
    }
}
