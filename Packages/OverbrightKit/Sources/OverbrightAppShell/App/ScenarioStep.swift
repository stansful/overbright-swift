// OverbrightAppShell/App/ScenarioStep.swift — DEBUG-only: one step of a scripted scenario over the simulated ports
// (`ScenarioScript` parses them, `ScenarioRunner` runs them). ARCHITECTURE.md §8.5, §10.15.
#if DEBUG
import OverbrightCore

/// One step of a scenario.
enum ScenarioStep: Equatable {
    case on, off, toggle, standard, brighter, lessBright, dimAll
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
    case loop
    case quit
}
#endif
