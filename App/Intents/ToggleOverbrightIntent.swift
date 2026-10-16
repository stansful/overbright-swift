// App/Intents/ToggleOverbrightIntent.swift — "Turn Overbright On or Off" (DESIGN.md §12.8). ARCHITECTURE.md §7.7,
// §10.10; D18. A one-line adapter: the logic is `IntentRouter` (OverbrightIntents), the strings are in
// App/Localizable.xcstrings (extracted metadata is localized against the app bundle).
import AppIntents
import OverbrightIntents

/// Turn Overbright On or Off (also the "Turn On or Off" App Shortcut and the Run Shortcut recipe of Help).
struct ToggleOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Overbright On or Off"
    static let description = IntentDescription("Turns extra brightness on or off.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process (it holds the displays' state).
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.toggle()
        return .result()
    }
}
