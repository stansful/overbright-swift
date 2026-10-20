// OverbrightSettingsUITests/Support/TestServices.swift — the services hub of `OverbrightServices.preview(fixture:)`
// with a chosen engine façade, and statuses the engine would publish once it has classified the fixture's displays
// (the preview engine publishes none: its displays read "Checking…" until a reading arrives).
import Foundation
import OverbrightCore
import OverbrightPolicy

/// Hubs and statuses for tests.
@MainActor enum TestServices {
    /// Every fake of `fixture`, with `boost` as the engine (and `announcer`, which says nothing by default).
    static func make(fixture: DisplayFixture = .builtinXDRLidOpen, boost: any BoostControl,
                     announcer: Announcer = Announcer(post: { _ in }, now: { 0 })) -> OverbrightServices {
        let services = OverbrightServices(
            settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(), machine: fixture.machine,
            time: ManualTimeSource(), journal: RingBufferJournal(), announcer: announcer,
            ownEDRSurfaces: OwnEDRSurfaces(), displays: FakeDisplayDirectory(fixture: fixture),
            signals: FakeSystemSignals(), boost: boost, fillLight: PreviewFillLightControl(),
            shortcuts: PreviewShortcutCenter(), updates: PreviewUpdateChecking())
        services.app = PreviewAppControl()
        return services
    }

    /// The preview hub of `fixture` whose engine publishes a reading and a classified decision for every display, as
    /// a running engine does (master off, every display idle at Standard).
    static func classified(_ fixture: DisplayFixture, isOn: Bool = false) -> OverbrightServices {
        let services = OverbrightServices.preview(fixture: fixture)
        guard let boost = services.boost as? PreviewBoostControl else { return services }
        let displays = fixture.displays.map { display -> DisplayStatus in
            let reading = display.headroom.hasOwnScreen
                ? HeadroomReading(display: display.facts.ref.id, current: display.headroom.idle,
                                  potential: display.headroom.potential, reference: display.headroom.reference,
                                  time: MonotonicInstant(sinceOrigin: .zero))
                : nil
            let eligibility = EligibilityClassifier.classify(display.facts, preferences: DisplayPreferences(),
                                                             reading: reading, machine: fixture.machine)
            let decision = DisplayDecision(key: display.key, target: .neutral, reasons: [.masterOff], eligibility: eligibility,
                                           domain: .encoded, requestedGain: 1)
            return DisplayStatus(key: display.key, name: display.facts.name, phase: .idle, decision: decision,
                                 appliedGain: 1, appliedFactor: 1, strategy: nil, lastReading: reading, sdrWhite: nil)
        }
        boost.status = BoostStatus(isOn: isOn, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: displays,
                                   banner: nil, symbol: isOn ? .on : .off)
        return services
    }

    /// A report with `results` for the built-in display, started at a fixed time.
    static func report(_ results: [SelfTestStrategyResult], display: DisplayKey = DisplayFixture.Keys.builtIn) -> SelfTestReport {
        SelfTestReport(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000), machine: DisplayFixture.ownerMachine,
                       appVersion: "0.1.0", displays: [display.rawValue: results], journal: [])
    }

    /// One rung's result.
    static func result(_ strategy: TriggerStrategy, _ pixel: TriggerPixel, _ verdict: SelfTestStrategyResult.Verdict,
                       movement: Double? = nil, stable: Double? = nil) -> SelfTestStrategyResult {
        SelfTestStrategyResult(strategy: strategy, pixel: pixel, verdict: verdict, baselineHeadroom: 1.2,
                               secondsToFirstMovement: movement, secondsToStable: stable,
                               heldFraction: verdict == .held ? 1 : 0, samples: [])
    }
}
