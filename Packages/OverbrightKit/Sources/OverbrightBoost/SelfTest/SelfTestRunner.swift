// OverbrightBoost/SelfTest/SelfTestRunner.swift — Advanced ▸ Run Self-Test. ARCHITECTURE.md §8.4; DESIGN.md §10.
// Seeded by WP0a with the fixed signatures (§10.0); owned by WP5, which writes the body (arm the ladder from the top,
// record H at 10 Hz per rung, verdicts, never a scaled write). The WP0a body returns an empty report.
import OverbrightCore

/// Measures every rung on the chosen displays through their drivers and returns a `SelfTestReport`.
public final class SelfTestRunner {
    private let drivers: [any DisplayControllerDriving]
    private let time: any TimeSource
    private let journal: any DiagnosticsJournal
    private let machine: MachineIdentity

    /// A runner over one driver per display.
    public init(drivers: [any DisplayControllerDriving], time: any TimeSource, journal: any DiagnosticsJournal,
                machine: MachineIdentity) {
        self.drivers = drivers; self.time = time; self.journal = journal; self.machine = machine
    }

    /// Runs the test. WP0a seed: an empty report, no display touched.
    public func run(_ options: SelfTestOptions) async -> SelfTestReport {
        _ = options
        return SelfTestReport(startedAt: time.wallClock, machine: machine, appVersion: AppInfo.current().version,
                              displays: [:], journal: [])
    }
}
