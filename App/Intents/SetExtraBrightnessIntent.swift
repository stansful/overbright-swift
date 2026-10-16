// App/Intents/SetExtraBrightnessIntent.swift — "Set Extra Brightness" (DESIGN.md §12.8). ARCHITECTURE.md §7.7,
// §10.10; D18. A one-line adapter over `IntentRouter`: a preset or a light multiplier, for a display or all of them;
// each display stops at its own limit.
import AppIntents
import OverbrightIntents

/// Set Extra Brightness.
struct SetExtraBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Extra Brightness"
    static let description = IntentDescription(
        "Sets the extra brightness of a display, or of every display. Each display stops at its own limit.")

    static var parameterSummary: some ParameterSummary {
        When(\.$level, .equalTo, .multiplier) {
            Summary("Set extra brightness of \(\.$display) to \(\.$level) ×\(\.$multiplier)")
        } otherwise: {
            Summary("Set extra brightness of \(\.$display) to \(\.$level)")
        }
    }

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    /// A display, or All Displays (also when empty).
    @Parameter(title: "Display")
    var display: DisplayEntity?

    /// A preset, or Multiplier.
    @Parameter(title: "Level", default: .brightRoom)
    var level: ExtraBrightnessLevel

    /// The light multiplier when Level is Multiplier (×1 is Standard).
    @Parameter(title: "Multiplier", default: 1.3, inclusiveRange: (1.0, 16.0))
    var multiplier: Double

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.setExtraBrightness(level.request(multiplier: multiplier), display: display?.key)
        return .result()
    }
}
