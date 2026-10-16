// App/Intents/PauseOverbrightIntent.swift — "Pause Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §4.9, §7.7, §10.10;
// D18. A one-line adapter over `IntentRouter` (the engine owns the pause deadline). The duration goes to the router as
// a plain number of seconds: `Duration.seconds(Double)` traps on an infinite, not-a-number or huge value, which a crafted
// shortcut can pass, so the router bounds it (§9.2 rule 2).
import AppIntents
import Foundation
import OverbrightIntents

/// Pause Overbright for a while.
struct PauseOverbrightIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Overbright"
    static let description = IntentDescription("Pauses extra brightness for a while.")

    static var parameterSummary: some ParameterSummary {
        Summary("Pause Overbright for \(\.$duration)")
    }

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    /// How long (one hour by default).
    @Parameter(title: "Duration", defaultValue: 60, defaultUnit: .minutes)
    var duration: Measurement<UnitDuration>

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.pause(forSeconds: duration.converted(to: .seconds).value)
        return .result()
    }
}
