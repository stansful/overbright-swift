// App/Intents/GetOverbrightStateIntent.swift — "Get Overbright State" (DESIGN.md §12.8). ARCHITECTURE.md §7.7,
// §10.10; D18. A one-line adapter over `IntentRouter`: the result value is on/off, the dialog names each display with
// the panel's own value text (Design's `ValueText`, DESIGN.md §1 principle 4), which this target passes to the router.
import AppIntents
import OverbrightDesign
import OverbrightIntents

/// Get Overbright State: "Overbright is on. Built-in Display: Bright room · ×1.29." / "Overbright is off."
struct GetOverbrightStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Overbright State"
    static let description = IntentDescription("Tells whether Overbright is on, and the level of each display.")

    /// Runs in the background: the app is never brought to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let report = try await router.stateReport { ValueText.make($0).text }
        return .result(value: report.isOn, dialog: "\(report.dialog)")
    }
}
