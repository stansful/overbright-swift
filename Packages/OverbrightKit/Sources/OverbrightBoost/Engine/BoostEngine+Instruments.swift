// OverbrightBoost/Engine/BoostEngine+Instruments.swift — the self-test, calibration and Reset Display Colors entry
// points, and the launch check's outcome. ARCHITECTURE.md §4.9 ("Calibration and self-test entry"), §7.4, §8.4,
// §10.0 (WP5's seams: `SelfTestRunner`, `CalibrationController`, `LaunchRescue`). MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension BoostEngine {
    /// Holds the master off, returns every display to Standard at once, runs the self-test over the chosen displays'
    /// controllers (which take no decisions meanwhile), leaves every display neutral, then restores the master switch.
    public func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport {
        let wasOn = isMasterOn
        holdForInstrument()
        let drivers = displays.displays
            .filter { options.displays?.contains($0.ref.key) ?? true }
            .compactMap { controllers[$0.ref.key] }
        for driver in drivers { driver.isDriven = true }
        let report = await SelfTestRunner(drivers: drivers, time: time, journal: journal, machine: machine).run(options)
        for driver in drivers {
            driver.isDriven = false
            driver.returnToStandard()
        }
        instrumentHold = false
        if wasOn { turnOn(source: .settings) }
        reduceNow()
        return report
    }

    /// Returns every display to Standard (triggers removed, neutral tables), hands the display's controller to the
    /// session and holds the master off until the session ends (`onEnd`); nil for a display without a controller or a
    /// transfer table, or while another session runs. Shield and removal events reach the session too.
    public func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? {
        guard calibrationSession == nil, let controller = controllers[display],
              controller.facts.gammaCapacity > 0 || controller.mechanism == .overlay else { return nil }
        holdForInstrument()
        controller.isDriven = true
        let session = CalibrationController(display: display, driver: controller, writer: writer, time: time,
                                            machine: machine)
        session.mechanism = controller.mechanism
        session.onEnd = { [weak self, weak controller] in
            controller?.isDriven = false
            controller?.stopNow()
            self?.calibrationEnded()
        }
        calibrationSession = session
        instrumentHold = false
        session.begin()
        return session
    }

    /// The calibration session ended: the master may turn on again.
    func calibrationEnded() {
        calibrationSession = nil
        journal.record("calibration.released", display: nil, time: time)
        reduceNow()
    }

    /// Advanced ▸ Reset Display Colors: every display to Standard, then dirty-then-restore with verification (D7);
    /// baselines are captured afresh on the next arm.
    public func rescueDisplayColors() async -> RescueOutcome {
        let wasOn = isMasterOn
        holdForInstrument()
        let rescue = LaunchRescue(gamma: gamma, conflicts: conflicts, signals: signals, journal: journal, time: time,
                                  displays: { [weak self] in self?.displays.displays.map(\.ref) ?? [] },
                                  settings: settings)
        let outcome = await rescue.rescueNow()
        for controller in controllers.values {
            controller.baseline = nil
            controller.lastWrite = nil
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
