// App/Intents/ResumeOverbrightIntent.swift — "Resume Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.10; D18.
// A one-line adapter over `IntentRouter`.
import AppIntents
import OverbrightIntents

/// Resume Overbright.
struct ResumeOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Overbright"
    static let description = IntentDescription("Ends a pause.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.resume()
        return .result()
    }
}
