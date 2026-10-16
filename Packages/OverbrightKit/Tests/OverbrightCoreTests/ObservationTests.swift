// OverbrightCoreTests/ObservationTests.swift — ported from Cranny's ObservationTests (the owner's MIT code), plus the
// closure-based ObservationToken of ARCHITECTURE.md §3.6 and OwnEDRSurfaces (§3.9).
import Foundation
import Observation
import Testing
@testable import OverbrightCore

@MainActor @Observable private final class Source {
    var value = 0
    var unrelated = 0
}

@MainActor private final class Probe {
    var evaluations = 0
    var delivered: [Int] = []
}

/// Lets the observer's follow-up task run (it hops back to the main actor after a change).
@MainActor private func settle(until condition: () -> Bool) async {
    for _ in 0..<200 where !condition() { await Task.yield() }
}

@MainActor @Suite("observe(_:onChange:)") struct ObservationTests {
    @Test func evaluatesTheValueOncePerRegistrationAndPerChange() async {
        let source = Source(), probe = Probe()
        let token = observe({ probe.evaluations += 1; return source.value }, onChange: { probe.delivered.append($0) })
        #expect(probe.evaluations == 1)                     // one pass reads and registers

        source.value = 1
        await settle { !probe.delivered.isEmpty }
        #expect(probe.delivered == [1])
        #expect(probe.evaluations == 2)                     // one pass per change, not two

        source.value = 2
        await settle { probe.delivered.count == 2 }
        #expect(probe.delivered == [1, 2] && probe.evaluations == 3)
        withExtendedLifetime(token) {}
    }

    @Test func deliversOnlyRealChangesAndStopsWhenCancelled() async {
        let source = Source(), probe = Probe()
        let token = observe({ probe.evaluations += 1; return source.value }, onChange: { probe.delivered.append($0) })
        source.value = 0                                    // the same value: nothing is delivered
        await settle { false }
        #expect(probe.delivered.isEmpty)
        let evaluations = probe.evaluations
        source.unrelated = 5                                // not read by the closure: not even evaluated
        await settle { false }
        #expect(probe.evaluations == evaluations)

        token.cancel()
        source.value = 3
        await settle { false }
        #expect(probe.delivered.isEmpty)
    }

    @Test func releasingTheTokenStopsObserving() async {
        let source = Source(), probe = Probe()
        var token: ObservationToken? = observe({ source.value }, onChange: { probe.delivered.append($0) })
        #expect(token != nil)
        token = nil
        source.value = 4
        await settle { false }
        #expect(probe.delivered.isEmpty)
    }

    @Test func aTokenRunsItsCancelActionOnce() {
        var runs = 0
        var token: ObservationToken? = ObservationToken { runs += 1 }
        token?.cancel()
        token?.cancel()
        token = nil                                         // deinit after cancel: nothing more
        #expect(runs == 1 && token == nil)
        _ = ObservationToken { runs += 1 }                  // released at once: deinit cancels
        #expect(runs == 2)
    }

    @Test func ownEDRSurfacesCountHoldsPerDisplay() {
        let surfaces = OwnEDRSurfaces()
        let display = DisplayKey(rawValue: "a-b")
        let first = surfaces.hold(display), second = surfaces.hold(display)
        #expect(surfaces.isHeld(display) && surfaces.displays[display] == 2)
        first.cancel()
        #expect(surfaces.isHeld(display))
        second.cancel()
        #expect(!surfaces.isHeld(display) && surfaces.displays.isEmpty)
    }
}

@MainActor @Suite("Announcer") struct AnnouncerTests {
    private final class Clock { var time: TimeInterval = 1000 }

    @Test func alertsAndResultsShareOneLimitFeedbackIsNeverLimited() {
        let clock = Clock()
        var posted: [String] = []
        let announcer = Announcer(post: { posted.append($0) }, now: { clock.time })
        #expect(announcer.announce("Paused because the battery is low", kind: .alert))
        clock.time += 3
        #expect(!announcer.announce("Self-test finished", kind: .result))     // another source, same 10-s window
        #expect(announcer.announce("Bright room", kind: .feedback))           // the user's own action: always
        clock.time += 6.9
        #expect(!announcer.announce("Turned off by the timer", kind: .result))
        clock.time += 0.1                                                     // 10 s after the alert
        #expect(announcer.announce("Extra brightness resumed", kind: .alert))
        #expect(!announcer.announce("", kind: .feedback))
        #expect(posted == ["Paused because the battery is low", "Bright room", "Extra brightness resumed"])
        #expect(Announcer.interval == 10)
    }

    @Test func previewServicesAnnounceNothing() {
        let services = OverbrightServices.preview()
        #expect(services.announcer.announce("a", kind: .alert))               // posted to a silent sink
    }
}
