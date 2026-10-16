// App/Intents/GetOverbrightStateIntent.swift — "Get Overbright State" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// Get Overbright State: on or off (WP8 adds each display's level to the dialog).
struct GetOverbrightStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Overbright State"
    static let description = IntentDescription("Tells whether Overbright is on, and the level of each display.")

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let isOn = try await router.state().isOn
        return .result(value: isOn, dialog: isOn ? "Overbright is on." : "Overbright is off.")
    }
}
