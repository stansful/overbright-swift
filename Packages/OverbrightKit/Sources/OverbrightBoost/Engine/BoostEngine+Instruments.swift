// OverbrightBoost/Engine/BoostEngine+Instruments.swift — the self-test, calibration and Reset Display Colors entry
// points, and the launch check's outcome. ARCHITECTURE.md §4.9 ("Calibration and self-test entry"), §7.4, §8.4,
// §10.0 (WP5's seams: `SelfTestRunner`, `CalibrationController`, `LaunchRescue`). MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension BoostEngine {
    /// Holds the master off, returns every display to Standard at once, runs the self-test over the chosen displays'
    /// controllers, leaves every display neutral, then restores the master switch.
    public func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport {
        let wasOn = isMasterOn
        holdForInstrument()
        let drivers = displays.displays
            .filter { options.displays?.contains($0.ref.key) ?? true }
            .compactMap { controllers[$0.ref.key] }
        let report = await SelfTestRunner(drivers: drivers, time: time, journal: journal, machine: machine).run(options)
        for driver in drivers { driver.returnToStandard() }
        instrumentHold = false
        if wasOn { turnOn(source: .settings) }
        reduceNow()
        return report
    }

    /// Returns every display to Standard (triggers removed, neutral tables) and holds the master off while the
    /// session lives; nil for a display without a controller or a transfer table.
    public func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? {
        guard let controller = controllers[display], controller.facts.gammaCapacity > 0 else { return nil }
        holdForInstrument()
        let session = CalibrationController(display: display, driver: controller, writer: writer, time: time,
                                            machine: machine)
        calibrationSession = session
        instrumentHold = false
        return session
    }

    /// Advanced ▸ Reset Display Colors: every display to Standard, then dirty-then-restore with verification (D7);
    /// baselines are captured afresh on the next arm.
    public func rescueDisplayColors() async -> RescueOutcome {
        let wasOn = isMasterOn
        holdForInstrument()
        let outcome = await LaunchRescue(gamma: gamma, conflicts: conflicts, signals: signals, journal: journal).rescueNow()
        for controller in controllers.values {
            controller.baseline = nil
            if controller.trip == .foreignTableAtLaunch { controller.clearTrip() }
        }
        applyLaunchCheck(outcome)
        instrumentHold = false
        if wasOn { turnOn(source: .settings) }
        reduceNow()
        return outcome
    }

    /// The launch check's outcome (the shell runs it before `start()`, §7.4): a display whose residue stayed is
    /// `failed(foreignTableAtLaunch)` until it reads as its profile base again.
    public func applyLaunchCheck(_ outcome: RescueOutcome) {
        journal.record("launch.checked", display: nil, time: time)
        guard case .residueRemains(let keys) = outcome else { return }
        for key in keys {
            if controllers[key] == nil, let facts = displays.facts(for: key) { controllers[key] = makeController(facts) }
            controllers[key]?.setTrip(.foreignTableAtLaunch)
        }
        if isStarted { scheduleReduce() }
    }

    /// Master off and every display back to Standard at once (baseline written, trigger removed).
    func holdForInstrument() {
        instrumentHold = true
        turnOff()
        for controller in controllers.values { controller.stopNow() }
        reduceNow()
    }
}
