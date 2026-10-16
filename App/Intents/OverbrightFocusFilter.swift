// App/Intents/OverbrightFocusFilter.swift — the Focus filter "Overbright" (DESIGN.md §12.8). ARCHITECTURE.md §7.7,
// §8.2, §10.10; D18. `perform()` is a one-line forward to `IntentRouter.focus(_:)` (→ `SystemSignals
// .setFocusDirective`, which Signals persists). v1 has no extension to receive a Focus change while Overbright is quit,
// so `OverbrightApp.init` reads `current` once at launch (`launchDirective()` through `IntentRouter.applyLaunchFocus`).
// No entitlement: Focus filters are not the Focus status API.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// Leave Alone (default) / Off / On at a level, while a Focus is on.
struct OverbrightFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Overbright"

    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, .on) {
            Summary {
                \.$mode
                \.$level
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }

    /// Never brings the app to the front.
    @available(macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    /// Always in the app process (v1 ships no extension).
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    /// Leave Alone, Off or On.
    @Parameter(title: "Overbright", default: .leaveAlone)
    var mode: FocusMode

    /// The level for On.
    @Parameter(title: "Level", default: .brightRoom)
    var level: FocusLevel

    @Dependency private var router: IntentRouter

    var displayRepresentation: DisplayRepresentation {
        switch (mode, level) {
        case (.leaveAlone, _): "Overbright: Leave Alone"
        case (.off, _): "Overbright: Off"
        case (.on, .indoor): "Overbright: On at Indoor"
        case (.on, .brightRoom): "Overbright: On at Bright Room"
        case (.on, .sunlight): "Overbright: On at Sunlight"
        case (.on, .max): "Overbright: On at Max"
        }
    }

    /// What the filter asks of Signals.
    var directive: FocusDirective {
        switch mode {
        case .leaveAlone: .leaveAlone
        case .off: .off
        case .on: .on(level: level.preset.position)
        }
    }

    /// The directive of the Focus that is on now (the launch-time read; throws when the system cannot tell).
    static func launchDirective() async throws -> FocusDirective { try await current.directive }

    @MainActor
    func perform() async throws -> some IntentResult {
        router.focus(directive)
        return .result()
    }
}
