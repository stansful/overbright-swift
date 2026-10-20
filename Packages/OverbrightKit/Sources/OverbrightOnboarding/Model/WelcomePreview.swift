// OverbrightOnboarding/Model/WelcomePreview.swift — preview hubs for the Welcome steps (#Previews, snapshot and flow
// tests). `OverbrightServices.preview(fixture:)` wires every Core fake, but its preview engine publishes no decisions;
// the real engine classifies every display while off (ARCHITECTURE.md §4.1, §6.1). Here each fixture display gets the
// verdict Policy's `EligibilityClassifier` gives it from the fixture's facts and idle reading, so the previews show
// the verdicts of DESIGN.md §12.1 without an engine. Nothing here touches hardware.
import OverbrightCore
import OverbrightPolicy

/// Preview services for Welcome.
enum WelcomePreview {
    /// A preview hub over `fixture`, plus the `adding` displays (step 2 with three or more displays), whose engine
    /// status carries a classified decision per display; with `updatesConfigured` the build behaves as if it had a
    /// repository (the update switch of step 5).
    static func services(_ fixture: DisplayFixture = .builtinXDRLidOpen, adding extra: [FixtureDisplay] = [],
                         updatesConfigured: Bool = false) -> OverbrightServices {
        let services = OverbrightServices.preview(fixture: fixture)
        (services.updates as? PreviewUpdateChecking)?.isConfigured = updatesConfigured
        if let directory = services.displays as? FakeDisplayDirectory {
            for display in extra { directory.add(display.facts) }
        }
        classify(services, machine: fixture.machine, scripts: fixture.displays + extra)
        return services
    }

    /// The owner's two displays (`.russianNames`) and a Studio Display XDR: step 2's three-display setup.
    static var threeDisplays: OverbrightServices {
        services(.russianNames, adding: DisplayFixture.studioDisplayXDR.displays)
    }

    /// Replaces the preview engine's display statuses with classified ones for `displays` (no-op for a real engine).
    static func classify(_ services: OverbrightServices, machine: MachineIdentity, scripts displays: [FixtureDisplay]) {
        guard let boost = services.boost as? PreviewBoostControl else { return }
        let stored = services.settings[DisplaySettings.perDisplay]
        boost.status.displays = displays.map { display in
            status(display, preferences: stored[display.key] ?? DisplayPreferences(), machine: machine)
        }
    }

    /// One display idle at Standard with its classifier decision (Overbright off).
    static func status(_ display: FixtureDisplay, preferences: DisplayPreferences,
                       machine: MachineIdentity) -> DisplayStatus {
        let facts = display.facts
        let reading = display.headroom.hasOwnScreen
            ? HeadroomReading(display: facts.ref.id, current: display.headroom.idle,
                              potential: display.headroom.potential, reference: display.headroom.reference,
                              time: MonotonicInstant(sinceOrigin: .zero))
            : nil
        let eligibility = EligibilityClassifier.classify(facts, preferences: preferences, reading: reading,
                                                         machine: machine)
        let decision = DisplayDecision(key: facts.ref.key, target: .neutral, reasons: [.masterOff],
                                       eligibility: eligibility, domain: .encoded, requestedGain: 1,
                                       level: preferences.level)
        return DisplayStatus(key: facts.ref.key, name: facts.name, phase: .idle, decision: decision, appliedGain: 1,
                             appliedFactor: 1, strategy: nil, lastReading: reading, sdrWhite: nil)
    }
}
