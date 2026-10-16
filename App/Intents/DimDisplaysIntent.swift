// App/Intents/DimDisplaysIntent.swift — "Dim Displays" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.1, §10.10; D18.
// Placeholder written by WP0a with the final type name, so `make smoke`'s metadata check finds every intent from the
// start; WP8 owns App/Intents/** and writes the real declaration (parameters, `supportedModes`,
// `allowedExecutionTargets`, strings in App/Localizable.xcstrings). `perform()` stays a one-line forward to the router.
import AppIntents
import OverbrightIntents

/// Dim Displays (placeholder: every display; WP8 adds the display parameter).
struct DimDisplaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Dim Displays"
    static let description = IntentDescription("Dims a display, or every display, below the macOS minimum.")

    @Parameter(title: "Brightness", default: 25, inclusiveRange: (2, 99))
    var percent: Int

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.dim(percent: percent, display: nil)
        return .result()
    }
}
