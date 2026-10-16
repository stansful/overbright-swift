// App/Intents/PauseOverbrightIntent.swift — "Pause Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightIntents
import Foundation

/// Pause Overbright for a while.
struct PauseOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Overbright"
    static let description = IntentDescription("Pauses extra brightness for a while.")

    @Parameter(title: "Duration", defaultValue: 60, defaultUnit: .minutes)
    var duration: Measurement<UnitDuration>

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.pause(for: .seconds(duration.converted(to: .seconds).value))
        return .result()
    }
}
