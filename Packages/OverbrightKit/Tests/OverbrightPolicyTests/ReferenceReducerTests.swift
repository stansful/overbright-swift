// OverbrightPolicyTests/ReferenceReducerTests.swift — TestSupport's reference reducer does what WP4's tests expect.
// ARCHITECTURE.md §10.1.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct ReferenceReducerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func input(master: Bool = true, level: LevelPosition = LevelPreset.max.position, boostEnabled: Bool? = nil,
                       system: SystemSnapshot? = nil, pausedUntil: Date? = nil, trip: TripCause? = nil,
                       fixture: DisplayFixture = .builtinXDRLidOpen) -> PolicyInput {
        let displays = fixture.displays.map { display in
            DisplayPolicyInput(facts: display.facts, preferences: DisplayPreferences(boostEnabled: boostEnabled, level: level),
                               feedback: EngineFeedback(trip: trip), sdrWhite: nil)
        }
        return PolicyInput(isMasterOn: master, pausedUntil: pausedUntil, now: now, minuteOfDay: 600,
                           machine: fixture.machine, settings: PolicySettings(),
                           system: system ?? SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: 90,
                                                                              isLowPowerMode: false)),
                           displays: displays, continuedEntryIDs: [])
    }
    private func target(_ decision: PolicyDecision) -> BoostTarget? {
        decision.displays[DisplayFixture.Keys.builtIn]?.target
    }

    @Test func masterOnBoostsToTopToThePowerOfTheLevel() throws {
        let decision = ReferenceReducer.reduce(input())
        #expect(decision.symbol == .on && decision.banner == nil)
        guard case .boost(let gain) = target(decision) else { Issue.record("not a boost"); return }
        #expect(abs(gain - ReferenceReducer.defaultTop) < 1e-12)
        let bright = ReferenceReducer(top: 2.587).decide(input(level: LevelPreset.brightRoom.position))
        guard case .boost(let g) = target(bright) else { Issue.record("not a boost"); return }
        #expect(abs(g - 1.608) < 0.001)
        let perDisplay = ReferenceReducer(tops: [DisplayFixture.Keys.builtIn: 2]).decide(input())
        #expect(target(perDisplay) == .boost(gain: 2))
    }

    @Test func dimLevelsDim() {
        let decision = ReferenceReducer.reduce(input(level: LevelPosition(-0.5)))
        guard case .dim(let light) = target(decision) else { Issue.record("not dim"); return }
        #expect(abs(light - 0.501) < 0.001 && decision.symbol == .dimming)
    }

    @Test func offShieldedPausedOrTrippedIsNeutral() {
        let power = PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: false)
        #expect(target(ReferenceReducer.reduce(input(master: false))) == .neutral)
        #expect(ReferenceReducer.reduce(input(master: false)).symbol == .off)
        #expect(target(ReferenceReducer.reduce(input(system: SystemSnapshot(power: power, isScreenLocked: true)))) == .neutral)
        #expect(target(ReferenceReducer.reduce(input(level: LevelPosition(-0.5),
                                                    system: SystemSnapshot(power: power, isSessionActive: false)))) == .neutral)
        let paused = ReferenceReducer.reduce(input(pausedUntil: now.addingTimeInterval(60)))
        #expect(target(paused) == .neutral && paused.symbol == .paused)
        #expect(paused.banner == .userPaused(until: now.addingTimeInterval(60)))
        #expect(target(ReferenceReducer.reduce(input(pausedUntil: now.addingTimeInterval(-1)))) != .neutral)  // expired
        #expect(target(ReferenceReducer.reduce(input(trip: .oscillation))) == .neutral)
        #expect(target(ReferenceReducer.reduce(input(boostEnabled: false))) == .neutral)
        #expect(ReferenceReducer.reduce(input(boostEnabled: false)).displays.values.first?.reasons == [.boostNotEnabled])
        #expect(target(ReferenceReducer.reduce(input(level: LevelPosition(-0.5), boostEnabled: false))) != .neutral)
        #expect(target(ReferenceReducer.reduce(input(level: .standard))) == .neutral)
    }

    @Test func displaysWithoutATableOrOwnScreenStayNeutral() {
        let sidecar = ReferenceReducer.reduce(input(fixture: .sidecar))
        #expect(sidecar.displays[DisplayFixture.Keys.sidecar]?.target == .neutral)
        let mirror = ReferenceReducer.reduce(input(fixture: .hardwareMirror))
        #expect(mirror.displays[DisplayFixture.Keys.projector]?.target == .neutral)
        let dimmedMirror = ReferenceReducer.reduce(input(level: LevelPosition(-0.5), fixture: .hardwareMirror))
        #expect(dimmedMirror.displays[DisplayFixture.Keys.projector]?.target != .neutral)       // dim only
    }
}
