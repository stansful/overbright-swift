// OverbrightAppShell/App/ScenarioStep.swift — DEBUG-only: one step of a scripted scenario over the simulated ports
// (`ScenarioScript` parses them, `ScenarioRunner` runs them). ARCHITECTURE.md §8.5, §10.15.
#if DEBUG
import OverbrightCore

/// One step of a scenario.
enum ScenarioStep: Equatable {
    case on, off, toggle, standard, brighter, lessBright, dimAll
    /// "Keep this level?" answered with Keep, as the HUD's button would (a display's first boost on a macOS build asks).
    case keep
    case level(LevelPosition)
    case dim(percent: Int)
    case boost(DisplayKey, Bool)
    case pause(seconds: Double)
    case resume
    case lock(Bool)
    case systemSleep(Bool)
    case screensSleep(Bool)
    case screensaver(Bool)
    case session(Bool)
    case event(SystemEvent)
    case lowPower(Bool)
    case battery(percent: Int?)
    case thermal(ThermalLevel)
    case fullScreen(video: Bool, display: DisplayKey?)
    case focus(FocusDirective)
    case conflict(ConflictSeverity?)
    case wait(seconds: Double)
    case dump(String)
    /// The panel under the icon opens (true) or closes; the app's QA hooks act on it, tests record it.
    case panel(Bool)
    /// Settings, Help or Welcome opens (true; at a pane, anchor or step, else its default) or closes as its close
    /// button would; the app's QA hooks act on it without taking focus, tests record it (`make perf`'s `windows`
    /// run, the soak's cycle: what a window leaves behind after it closes, DESIGN.md §17).
    case window(ScenarioWindow, open: Bool, at: String? = nil)
    case loop
    case quit
}

/// The windows a scenario opens and closes.
enum ScenarioWindow: String, Equatable, CaseIterable {
    case settings, help, welcome
}
#endif
