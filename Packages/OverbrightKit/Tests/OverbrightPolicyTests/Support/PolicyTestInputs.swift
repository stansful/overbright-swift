// OverbrightPolicyTests/Support/PolicyTestInputs.swift — builders for reducer inputs over Core's display fixtures.
// ARCHITECTURE.md §3.9, §6.1. Conflicting apps use synthetic bundle IDs only (D3).
import CoreGraphics
import Foundation
import OverbrightCore

/// Reducer inputs with readable defaults: the owner's Mac, on the adapter, master on, nothing shielded or paused.
nonisolated enum PolicyTestInputs {
    static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let adapter = PowerState(source: .adapter, batteryPercent: 90, isLowPowerMode: false)
    static let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0]
    static let msi = DisplayFixture.mpg322uxHDROn.displays[0]
    static let projector = DisplayFixture.hardwareMirror.displays[1]

    static func system(power: PowerState = adapter) -> SystemSnapshot { SystemSnapshot(power: power) }

    /// A reading of `display` at the fixture's potential: at the grant (`granted`) or idle.
    static func reading(_ display: FixtureDisplay, current: Double? = nil, granted: Bool = true,
                        potential: Double? = nil, reference: Double? = nil) -> HeadroomReading {
        let script = display.headroom
        return HeadroomReading(display: display.facts.ref.id,
                               current: current ?? (granted ? script.grant : script.idle),
                               potential: potential ?? script.potential, reference: reference ?? script.reference,
                               time: MonotonicInstant(sinceOrigin: .zero))
    }

    /// One display's input: the fixture's facts, a reading at the grant (none for a display without its own
    /// screen), and the given preferences.
    static func display(_ display: FixtureDisplay = builtIn, level: LevelPosition = LevelPreset.brightRoom.position,
                        boostEnabled: Bool? = nil, capMode: CapMode = .safe, oled: OLEDOverride = .automatic,
                        calibration: CalibrationRecord? = nil, trip: TripCause? = nil, reading: HeadroomReading?? = nil,
                        sdrWhite: SDRWhiteEstimate? = nil) -> DisplayPolicyInput {
        let preferences = DisplayPreferences(boostEnabled: boostEnabled, level: level, capMode: capMode,
                                             calibration: calibration, oled: oled)
        let defaultReading = display.headroom.hasOwnScreen ? Self.reading(display) : nil
        return DisplayPolicyInput(facts: display.facts, preferences: preferences,
                                  feedback: EngineFeedback(trip: trip, lastReading: reading ?? defaultReading),
                                  sdrWhite: sdrWhite)
    }

    static func input(_ displays: [DisplayPolicyInput] = [display()], master: Bool = true,
                      settings: PolicySettings = PolicySettings(), system: SystemSnapshot = system(),
                      pausedUntil: Date? = nil, minuteOfDay: Int = 600,
                      machine: MachineIdentity = DisplayFixture.ownerMachine,
                      continued: Set<String> = []) -> PolicyInput {
        PolicyInput(isMasterOn: master, pausedUntil: pausedUntil, now: now, minuteOfDay: minuteOfDay, machine: machine,
                    settings: settings, system: system, displays: displays, continuedEntryIDs: continued)
    }

    /// A conflicting app with a synthetic identity (never a real catalogue ID, D3).
    static func app(_ severity: ConflictSeverity, entry: String = "test-entry", pid: Int32 = 4242) -> ConflictingApp {
        ConflictingApp(entryID: entry, severity: severity, bundleID: "com.example.\(severity.rawValue)",
                       processID: pid, displayName: "Example")
    }

    /// The frontmost app on `displays`.
    static func front(_ bundleID: String, on displays: Set<DisplayKey>, isPlaying: Bool? = nil,
                      isGame: Bool = false) -> FrontmostApp {
        FrontmostApp(bundleID: bundleID, processID: 77, displays: displays, isPlaying: isPlaying, isGame: isGame)
    }

    /// A linear calibration record valid on the owner's Mac at the built-in's potential.
    static func record(_ outcome: CalibrationRecord.Outcome, build: String = DisplayFixture.ownerMachine.osBuild,
                       potential: Double = 16, sdrWhite: Double? = nil) -> CalibrationRecord {
        CalibrationRecord(outcome: outcome, mergeFactor: 1.613, estimatedExponent: 2.2,
                          measuredSDRWhiteNits: sdrWhite, headroomAtTest: 2.667, potentialAtTest: potential,
                          osBuild: build, measuredAt: Date(timeIntervalSinceReferenceDate: 0))
    }
}

extension PolicyDecision {
    /// The decision of the fixtures' built-in display.
    var builtIn: DisplayDecision? { displays[DisplayFixture.Keys.builtIn] }
}

extension DisplayDecision {
    /// The boost gain, or nil for any other target.
    var boostGain: Double? { if case .boost(let gain) = target { gain } else { nil } }
    /// The dim light, or nil for any other target.
    var dimLight: Double? { if case .dim(let light) = target { light } else { nil } }
}
