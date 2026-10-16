// OverbrightAppShell/App/ScenarioScript.swift — DEBUG-only: a scripted scenario over the simulated ports
// (`--qa-script "<steps>"`, ARCHITECTURE.md §8.5) and the same steps in `EndToEndScenarioTests`, so the QA matrix and
// the tests run one script. Steps are separated by `;`; each is a word and its arguments:
//
//   on | off | toggle | standard | brighter | less | dim-all      the engine, as a global shortcut would
//   level <standard|indoor|bright-room|sunlight|max|-1…1>        every display's level, as the panel would
//   dim <2…99>                                                   every display dimmed to that % of Standard light
//   boost <display> on|off                                       a display's "Use extra brightness" switch
//   pause <seconds> | resume
//   lock | unlock | sleep | wake | screens-sleep | screens-wake | screensaver on|off | session off|on
//   event <reconfigured|configuration-began|removed <display>|profile|screen-parameters|space|accessibility>
//   low-power on|off | battery <percent>|adapter | thermal nominal|fair|serious|critical
//   full-screen video|app|none <display> | focus off|leave|<level> | conflict booster|writer|conditional|none
//   wait <seconds> | dump <label> | loop | quit
//
// Displays are named by fixture role: built-in, msi, pro, studio, sidecar, projector. Nothing here reaches a real
// display: a script runs only when the ports are the Core fakes (`ScenarioRunner.Rig`).
#if DEBUG
import Foundation
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

/// Parses scenario scripts.
enum ScenarioScript {
    /// A step that could not be read.
    struct ParseError: Error, Equatable, CustomStringConvertible {
        /// The step as written.
        let step: String
        var description: String { "unreadable scenario step \"\(step)\"" }
    }

    /// The steps of `text` (see the file header).
    static func parse(_ text: String) throws -> [ScenarioStep] {
        try text.split(separator: ";").compactMap { raw in
            let words = raw.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let word = words.first else { return nil }
            guard let step = step(word, Array(words.dropFirst())) else { throw ParseError(step: raw.trimmed) }
            return step
        }
    }

    /// The fixture role names of the displays.
    static let displays: [String: DisplayKey] = [
        "built-in": DisplayFixture.Keys.builtIn, "msi": DisplayFixture.Keys.mpg322ux,
        "pro": DisplayFixture.Keys.proDisplayXDR, "studio": DisplayFixture.Keys.studioDisplayXDR,
        "sidecar": DisplayFixture.Keys.sidecar, "projector": DisplayFixture.Keys.projector,
    ]

    /// The step a first word and its arguments name; nil for an unknown word or bad arguments.
    private static func step(_ word: String, _ args: [String]) -> ScenarioStep? {
        let first = args.first
        switch word {
        case "on": return .on
        case "off": return .off
        case "toggle": return .toggle
        case "standard": return .standard
        case "brighter": return .brighter
        case "less": return .lessBright
        case "dim-all": return .dimAll
        case "level": return first.flatMap(level).map(ScenarioStep.level)
        case "dim": return first.flatMap { Int($0) }.map { .dim(percent: $0) }
        case "boost":
            guard let key = first.flatMap({ displays[$0] }), let on = args.dropFirst().first.flatMap(onOff) else { return nil }
            return .boost(key, on)
        case "pause": return first.flatMap { Double($0) }.map { .pause(seconds: $0) }
        case "resume": return .resume
        case "lock": return .lock(true)
        case "unlock": return .lock(false)
        case "sleep": return .systemSleep(true)
        case "wake": return .systemSleep(false)
        case "screens-sleep": return .screensSleep(true)
        case "screens-wake": return .screensSleep(false)
        case "screensaver": return first.flatMap(onOff).map(ScenarioStep.screensaver)
        case "session": return first.flatMap(onOff).map(ScenarioStep.session)
        case "event": return event(args)
        case "low-power": return first.flatMap(onOff).map(ScenarioStep.lowPower)
        case "battery": return first == "adapter" ? .battery(percent: nil) : first.flatMap { Int($0) }.map { .battery(percent: $0) }
        case "thermal": return first.flatMap(thermal).map(ScenarioStep.thermal)
        case "full-screen": return fullScreen(args)
        case "focus": return first.flatMap(focus).map(ScenarioStep.focus)
        case "conflict": return first.flatMap(conflict).map(ScenarioStep.conflict)
        case "wait": return first.flatMap { Double($0) }.map { .wait(seconds: $0) }
        case "dump": return .dump(args.joined(separator: " "))
        case "loop": return .loop
        case "quit": return .quit
        default: return nil
        }
    }

    private static func onOff(_ word: String) -> Bool? { word == "on" ? true : word == "off" ? false : nil }

    private static func level(_ word: String) -> LevelPosition? {
        let presets: [String: LevelPreset] = ["standard": .standard, "indoor": .indoor, "bright-room": .brightRoom,
                                              "sunlight": .sunlight, "max": .max]
        if let preset = presets[word] { return preset.position }
        guard let value = Double(word), value.isFinite, (-1...1).contains(value) else { return nil }
        return LevelPosition(value)
    }

    private static func thermal(_ word: String) -> ThermalLevel? {
        ["nominal": .nominal, "fair": .fair, "serious": .serious, "critical": .critical][word]
    }

    private static func focus(_ word: String) -> FocusDirective? {
        switch word {
        case "off": return .off
        case "leave": return .leaveAlone
        default: return level(word).map { .on(level: $0) }
        }
    }

    /// The severity a word names; `.some(nil)` for "none", nil for an unknown word.
    private static func conflict(_ word: String) -> ConflictSeverity?? {
        switch word {
        case "booster": .some(.booster)
        case "writer": .some(.gammaWriter)
        case "conditional": .some(.conditional)
        case "none": .some(.none)
        default: .none
        }
    }

    private static func fullScreen(_ args: [String]) -> ScenarioStep? {
        guard let kind = args.first else { return nil }
        if kind == "none" { return .fullScreen(video: false, display: nil) }
        guard kind == "video" || kind == "app" else { return nil }
        let display = args.dropFirst().first.flatMap { displays[$0] } ?? DisplayFixture.Keys.builtIn
        return .fullScreen(video: kind == "video", display: display)
    }

    private static func event(_ args: [String]) -> ScenarioStep? {
        switch args.first {
        case "reconfigured": return .event(.displaysReconfigured)
        case "configuration-began": return .event(.displayConfigurationBegan)
        case "profile": return .event(.colorProfileChanged)
        case "screen-parameters": return .event(.screenParametersChanged)
        case "space": return .event(.activeSpaceChanged)
        case "accessibility": return .event(.accessibilityDisplayOptionsChanged)
        case "removed":
            guard let key = args.dropFirst().first.flatMap({ displays[$0] }),
                  let id = DisplayFixture.allCases.lazy.flatMap(\.displays).first(where: { $0.key == key })?.facts.ref.id
            else { return nil }
            return .event(.displayRemoved(id))
        default: return nil
        }
    }
}

private extension Substring {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
#endif
