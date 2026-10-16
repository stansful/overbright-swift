// App/Intents/TurnOnOverbrightIntent.swift — "Turn On Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.10; D18.
// A one-line adapter over `IntentRouter`; a turn-on from an intent overrides "Launch, keep off" (the router waits for
// the launch work first).
import AppIntents
import OverbrightIntents

/// Turn On Overbright.
struct TurnOnOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Overbright"
    static let description = IntentDescription("Turns Overbright on. Each display uses its own level.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.turnOn()
        return .result()
    }
}
