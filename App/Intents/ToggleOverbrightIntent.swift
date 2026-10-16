// App/Intents/ToggleOverbrightIntent.swift — "Turn Overbright On or Off" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightIntents

/// Turn Overbright On or Off.
struct ToggleOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Overbright On or Off"
    static let description = IntentDescription("Turns extra brightness on or off.")

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.toggle()
        return .result()
    }
}
