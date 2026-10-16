// App/Intents/TurnOffOverbrightIntent.swift — "Turn Off Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.10;
// D18. A one-line adapter over `IntentRouter`.
import AppIntents
import OverbrightIntents

/// Turn Off Overbright.
struct TurnOffOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Overbright"
    static let description = IntentDescription("Turns Overbright off. Your displays return to Standard.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.turnOff()
        return .result()
    }
}
