// OverbrightPolicyTests/ReducerPropertyTests.swift — the reducer's properties over 10 000 seeded random inputs
// (ARCHITECTURE.md §9.1): never `.boost` while shielded, off, paused or tripped; every stop yields neutral; guards and
// the boost switch never block dimming; per-display rules never touch other displays; names change nothing; the
// static caps hold; the reducer is a pure function. Each case's seed is its index, so a failure names its seed.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct ReducerPropertyTests {
    private static let seeds = 10_000

    @Test func reducerProperties() {
        var boosted = 0, dimmed = 0, stopped = 0
        for seed in 0..<Self.seeds {
            var random = SeededGenerator(seed: UInt64(seed))
            let input = RandomPolicyInput.make(using: &random)
            let decision = BoostPolicy.reduce(input)
            #expect(decision == BoostPolicy.reduce(input), "seed \(seed): not a pure function")
            #expect(decision.displays.count == input.displays.count, "seed \(seed)")
            #expect((decision.symbol == .off) == !input.isMasterOn && decision.symbol != .preparing, "seed \(seed)")
            if !input.isMasterOn { #expect(decision.banner == nil, "seed \(seed)") }
            for display in input.displays {
                guard let result = decision.displays[display.facts.ref.key] else { continue }
                check(result, display, input, seed: seed)
                switch result.target {
                case .boost: boosted += 1
                case .dim: dimmed += 1
                case .neutral: if !result.reasons.isEmpty { stopped += 1 }
                }
            }
            checkIsolation(input, decision, seed: seed, using: &random)
            checkNamesChangeNothing(input, decision, seed: seed)
        }
        // Not vacuous: every kind of outcome occurs often.
        #expect(boosted > 1_000 && dimmed > 2_500 && stopped > 10_000, "\(boosted) / \(dimmed) / \(stopped)")
    }

    private func check(_ result: DisplayDecision, _ display: DisplayPolicyInput, _ input: PolicyInput, seed: Int) {
        let paused = input.pausedUntil.map { $0 > input.now } ?? false
        let isStop: (LimitReason) -> Bool = { reason in
            switch reason {
            case .masterOff, .notSupported, .shielded, .tripped, .userPaused, .focusOff: true
            case .conflict(let app): app.severity == .booster || app.severity == .gammaWriter
            default: false
            }
        }
        // Never a boost (nor a dim) while off, shielded, paused or tripped; every stop and guard is neutral.
        if !input.isMasterOn || input.system.isShielded || paused || display.feedback.trip != nil {
            #expect(result.target == .neutral, "seed \(seed): \(result.target)")
        }
        let hasStop = result.reasons.contains(where: isStop)
        let hasGuard = result.reasons.contains { $0.blocksBoostOnly }
        if hasStop { #expect(result.target == .neutral, "seed \(seed)") }
        if hasGuard { #expect(result.target == .neutral && result.level.isBoost, "seed \(seed): \(result.reasons)") }
        // Guards and the boost switch never block dimming: a dim level is dimmed unless a real stop applies.
        if result.level.isDim {
            let dims = result.dimLight != nil
            #expect(!hasGuard && dims == !hasStop, "seed \(seed): \(result.reasons)")
        }
        let oled = EligibilityClassifier.isOLED(display.facts, override: display.preferences.oled)
        let top = GainCeiling.sliderTop(facts: display.facts, capMode: display.preferences.capMode, isOLED: oled)
        switch result.target {
        case .boost(let gain):
            #expect(result.level.isBoost && result.eligibility.verdict.allowsBoost, "seed \(seed)")
            #expect(gain >= DisplayReducer.noOpGain && gain <= result.requestedGain + 1e-12, "seed \(seed)")
            #expect(abs(result.requestedGain - pow(top, result.level.value)) < 1e-9, "seed \(seed)")
            if input.system.thermal == .serious { #expect(gain <= GainCeiling.thermalSeriousGain, "seed \(seed)") }
            if display.preferences.capMode == .safe, let sdr = display.sdrWhite,
               let capNits = GainCeiling.capNits(facts: display.facts, isOLED: oled) {
                #expect(gain <= max(capNits / sdr.nits, 1) + 1e-12, "seed \(seed)")
            }
        case .dim(let light):
            #expect(result.level.isDim && result.eligibility.verdict.allowsDim, "seed \(seed)")
            #expect(light >= LevelMapping.minimumDimLight && light < 1, "seed \(seed)")
        case .neutral:
            break
        }
        if result.target != .neutral { #expect(input.isMasterOn) }
    }

    /// A per-display change (a trip, a full-screen window, the boost switch, the level, the cap mode) on one display
    /// leaves every other display's decision as it was.
    private func checkIsolation(_ input: PolicyInput, _ decision: PolicyDecision, seed: Int,
                                using random: inout SeededGenerator) {
        guard input.displays.count > 1, let index = input.displays.indices.randomElement(using: &random) else { return }
        var changed = input
        let key = input.displays[index].facts.ref.key
        switch Int.random(in: 0..<5, using: &random) {
        case 0: changed.displays[index].feedback.trip = .oscillation
        case 1:
            changed.system.fullScreenDisplays.insert(key)
            changed.system.fullScreenVideoDisplays.insert(key)
        case 2: changed.displays[index].preferences.boostEnabled = false
        case 3: changed.displays[index].preferences.level = LevelPosition(-0.75)
        default: changed.displays[index].preferences.capMode = .peak
        }
        let after = BoostPolicy.reduce(changed)
        for display in input.displays where display.facts.ref.key != key {
            let other = display.facts.ref.key
            #expect(after.displays[other] == decision.displays[other], "seed \(seed): \(other) changed")
        }
    }

    /// No name logic (D8, §4.5 invariant 10): renaming every display changes no decision.
    private func checkNamesChangeNothing(_ input: PolicyInput, _ decision: PolicyDecision, seed: Int) {
        var renamed = input
        for index in renamed.displays.indices {
            renamed.displays[index].facts.name = index.isMultiple(of: 2) ? "Встроенный дисплей" : "Sidecar · OLED · XDR"
        }
        #expect(BoostPolicy.reduce(renamed) == decision, "seed \(seed)")
    }
}

/// Random reducer inputs over the fixture displays (distinct keys), with every guard, rule, trip and conflict.
private nonisolated enum RandomPolicyInput {
    static let displays: [FixtureDisplay] = [
        DisplayFixture.builtinXDRLidOpen.displays[0], DisplayFixture.mpg322uxHDROn.displays[0],
        DisplayFixture.proDisplayXDR.displays[0], DisplayFixture.studioDisplayXDR.displays[0],
        DisplayFixture.sidecar.displays[1], DisplayFixture.hardwareMirror.displays[1],
    ]
    static let trips: [TripCause] = [.oscillation, .repairBudgetExceeded, .headroomNeverArrived, .foreignTableAtLaunch,
                                     .attributedDrift(PolicyTestInputs.app(.conditional, entry: "s3"))]
    static let apps: [ConflictingApp] = [PolicyTestInputs.app(.booster, entry: "s1"),
                                         PolicyTestInputs.app(.gammaWriter, entry: "s2"),
                                         PolicyTestInputs.app(.conditional, entry: "s3"),
                                         PolicyTestInputs.app(.benign, entry: "s4")]

    static func make(using random: inout SeededGenerator) -> PolicyInput {
        let count = Int.random(in: 1...4, using: &random)
        let chosen = Array(displays.shuffled(using: &random).prefix(count))
        let inputs = chosen.map { display($0, using: &random) }
        let now = PolicyTestInputs.now
        let isMasterOn = chance(0.9, &random)
        let pausedUntil = chance(0.1, &random) ? pick([now.addingTimeInterval(600), now.addingTimeInterval(-600)], &random) : nil
        let minuteOfDay = Int.random(in: 0..<1440, using: &random)
        let machine = chance(0.1, &random) ? DisplayFixture.neoIgnoresWrites.machine : DisplayFixture.ownerMachine
        let settings = settings(using: &random)
        let system = system(chosen.map(\.facts.ref.key), using: &random)
        let continued: Set<String> = chance(0.3, &random) ? ["s1", "s2", "s3"] : []
        return PolicyInput(isMasterOn: isMasterOn, pausedUntil: pausedUntil, now: now, minuteOfDay: minuteOfDay,
                           machine: machine, settings: settings, system: system, displays: inputs,
                           continuedEntryIDs: continued)
    }

    private static func display(_ display: FixtureDisplay, using random: inout SeededGenerator) -> DisplayPolicyInput {
        let level: LevelPosition = switch Int.random(in: 0..<6, using: &random) {
        case 0: .standard
        case 1, 2: pick(LevelPreset.allCases, &random).position
        case 3: LevelPosition(-Double.random(in: 0...1, using: &random))
        case 4: LevelPosition(Double.random(in: 0...1, using: &random))
        default: LevelPosition(Double.random(in: -1...1, using: &random))
        }
        let preferences = DisplayPreferences(
            boostEnabled: pick([nil, nil, true, true, false], &random), level: level,
            capMode: pick(CapMode.allCases, &random),
            calibration: chance(0.3, &random)
                ? PolicyTestInputs.record(pick([.encoded, .linear, .inconclusive, .notBrighter], &random),
                                          potential: display.headroom.potential) : nil,
            oled: pick([.automatic, .automatic, .oled, .notOLED], &random))
        let script = display.headroom
        let reading: HeadroomReading? = !script.hasOwnScreen || chance(0.1, &random) ? nil
            : HeadroomReading(display: display.facts.ref.id,
                              current: Double.random(in: 1...max(script.potential, 1.0001), using: &random),
                              potential: chance(0.05, &random) ? Double.random(in: 0...3, using: &random) : script.potential,
                              reference: chance(0.05, &random) ? 4 : 0, time: MonotonicInstant(sinceOrigin: .zero))
        return DisplayPolicyInput(facts: display.facts, preferences: preferences,
                                  feedback: EngineFeedback(trip: chance(0.08, &random) ? pick(trips, &random) : nil,
                                                           lastReading: reading),
                                  sdrWhite: chance(0.2, &random)
                                      ? SDRWhiteEstimate(nits: Double.random(in: 200...1200, using: &random),
                                                         source: .colorimeter) : nil)
    }

    private static func settings(using random: inout SeededGenerator) -> PolicySettings {
        PolicySettings(batteryGuard: pick(BatteryGuard.allCases, &random),
                       batteryThreshold: 5 * Int.random(in: 1...19, using: &random),
                       pauseInLowPowerMode: chance(0.8, &random), pauseForFullScreenVideo: chance(0.8, &random),
                       pauseForAllFullScreen: chance(0.3, &random), pauseInGames: chance(0.3, &random),
                       pauseForListedApps: chance(0.8, &random),
                       pausedApps: [PausedAppRule(bundleID: "com.example.Player", mode: .whilePlaying),
                                    PausedAppRule(bundleID: "com.example.Editor", mode: .whileFrontmost,
                                                  isEnabled: chance(0.8, &random))],
                       schedule: chance(0.15, &random)
                           ? ScheduleWindow(startMinute: Int.random(in: 0..<1440, using: &random),
                                            endMinute: Int.random(in: 0..<1440, using: &random)) : nil,
                       linkLevels: chance(0.2, &random), linkedLevel: LevelPosition(Double.random(in: -1...1, using: &random)),
                       boostOnlyNearFullBrightness: chance(0.7, &random),
                       alwaysContinueEntryIDs: chance(0.2, &random) ? ["s1", "s2", "s3"] : [])
    }

    private static func system(_ keys: [DisplayKey], using random: inout SeededGenerator) -> SystemSnapshot {
        func some(_ random: inout SeededGenerator) -> Set<DisplayKey> {
            var set: Set<DisplayKey> = []
            for key in keys where chance(0.2, &random) { set.insert(key) }
            return set
        }
        let fullScreen = some(&random)
        var video: Set<DisplayKey> = []
        for key in fullScreen where chance(0.5, &random) { video.insert(key) }
        let source: PowerSourceKind = pick([.adapter, .adapter, .adapter, .battery, .ups, .unknown], &random)
        let percent = chance(0.8, &random) ? Int.random(in: 0...100, using: &random) : nil
        let power = PowerState(source: source, batteryPercent: percent, isLowPowerMode: chance(0.08, &random))
        var front: FrontmostApp?
        if chance(0.5, &random) {
            let bundleID = pick(["com.example.Player", "com.example.Editor", "com.example.Other", nil], &random)
            let displays = some(&random)
            let playing = pick([nil, true, false], &random)
            front = FrontmostApp(bundleID: bundleID, processID: 99, displays: displays, isPlaying: playing,
                                 isGame: chance(0.2, &random))
        }
        var conflicts: [ConflictingApp] = []
        for app in apps where chance(0.05, &random) { conflicts.append(app) }
        let focusLevel = LevelPosition(Double.random(in: -1...1, using: &random))
        let focus = pick([FocusDirective.leaveAlone, .leaveAlone, .leaveAlone, .leaveAlone, .leaveAlone, .leaveAlone, .off,
                          .on(level: focusLevel)], &random)
        let thermal = pick([ThermalLevel.nominal, .nominal, .nominal, .nominal, .fair, .serious, .serious, .critical], &random)
        let locked = chance(0.03, &random), screensaver = chance(0.02, &random), asleep = chance(0.02, &random)
        let sleeping = chance(0.01, &random), active = !chance(0.02, &random), idle = chance(0.2, &random)
        let suppressed = chance(0.1, &random)
        return SystemSnapshot(power: power, thermal: thermal, isScreenLocked: locked, isScreensaverRunning: screensaver,
                              areDisplaysAsleep: asleep, isSystemSleeping: sleeping, isSessionActive: active,
                              frontmost: front, fullScreenDisplays: fullScreen, fullScreenVideoDisplays: video,
                              isIdleBeyondThreshold: idle, conflicts: conflicts, focus: focus,
                              isHDRSuppressed: suppressed)
    }

    private static func chance(_ probability: Double, _ random: inout SeededGenerator) -> Bool {
        Double.random(in: 0..<1, using: &random) < probability
    }
    private static func pick<Element>(_ options: [Element], _ random: inout SeededGenerator) -> Element {
        options[Int.random(in: 0..<options.count, using: &random)]
    }
}
