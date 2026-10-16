// Shared/BoostControlIntent.swift — the dormant control's action, a member of both the app target and the
// OverbrightControls extension (one synchronized folder in both targets). ARCHITECTURE.md §7.7, D18, D25.
// In the app process (`OVERBRIGHT_APP`) it is a one-line forward to the router. In the extension process
// (`OVERBRIGHT_CONTROLS`: macOS 26, when the system picks the extension) it hands the request to the app through
// `overbright://control` and waits up to 1 s for the published state (`ControlHandOff`, Controls/). On macOS 27
// `allowedExecutionTargets = .main` keeps it in the app. Its strings are in both catalogs (App/ and Controls/).
import AppIntents
#if OVERBRIGHT_APP
import OverbrightIntents
#endif

/// Turns extra brightness on or off from the Control Center control. The same type name in both bundles gives the
/// same intent identifier in both metadata sets.
@available(macOS 26.0, *)
struct BoostControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Extra Brightness"
    /// The Shortcuts-facing intents live in App/Intents; this one only serves the control.
    static let isDiscoverable = false

    /// Never brings the app to the front.
    static var supportedModes: IntentModes { .background }

    /// macOS 27+: always the app process (it launches Overbright when it is not running).
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    /// On or off.
    @Parameter(title: "Extra Brightness")
    var value: Bool

    #if OVERBRIGHT_APP
    @Dependency private var router: IntentRouter
    #endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if OVERBRIGHT_APP
        try await router.setOn(value)
        #else
        await ControlHandOff.request(on: value)
        #endif
        return .result()
    }
}
