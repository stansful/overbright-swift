// App/Intents/DimDisplaysIntent.swift — "Dim Displays" (DESIGN.md §12.8). ARCHITECTURE.md §7.7, §10.10; D11, D18.
// A one-line adapter over `IntentRouter`: a light percentage of Standard (2–99), for a display or every display that
// can dim. Below 10 % the engine asks "Keep this level?" as from any surface.
import AppIntents
import OverbrightIntents

/// Dim Displays.
struct DimDisplaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Dim Displays"
    static let description = IntentDescription("Dims a display, or every display, below the macOS minimum.")

    static var parameterSummary: some ParameterSummary {
        Summary("Dim \(\.$display) to \(\.$percent)")
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

    /// Percent of Standard light.
    @Parameter(title: "Brightness", default: 25, inclusiveRange: (2, 99))
    var percent: Int

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        try await router.dim(percent: percent, display: display?.key)
        return .result()
    }
}
