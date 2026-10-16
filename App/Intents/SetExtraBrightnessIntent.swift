// App/Intents/SetExtraBrightnessIntent.swift — "Set Extra Brightness" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// Set Extra Brightness (placeholder: a multiplier for every display; WP8 adds the preset choice and the display).
struct SetExtraBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Extra Brightness"
    static let description = IntentDescription(
        "Sets the extra brightness of a display, or of every display. Each display stops at its own limit.")

    @Parameter(title: "Multiplier", default: 1.3)
    var multiplier: Double

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.setExtraBrightness(.multiplier(multiplier), display: nil)
        return .result()
    }
}
