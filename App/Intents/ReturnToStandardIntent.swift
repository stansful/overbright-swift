// App/Intents/ReturnToStandardIntent.swift — "Back to Standard" (DESIGN.md §12.8). ARCHITECTURE.md §4.9, §7.4, §7.7,
// §10.10; D18. A one-line adapter over `IntentRouter`; also the "Back to Standard" App Shortcut.
import AppIntents
import OverbrightIntents

/// Back to Standard: master off at once, dims undone, levels kept.
struct ReturnToStandardIntent: AppIntent {
    static let title: LocalizedStringResource = "Back to Standard"
    static let description = IntentDescription("Turns Overbright off at once. Your levels are kept for next time.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.returnToStandard()
        return .result()
    }
}
