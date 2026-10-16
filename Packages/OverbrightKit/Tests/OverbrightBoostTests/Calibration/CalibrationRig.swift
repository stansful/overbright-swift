// OverbrightBoostTests/Calibration/CalibrationRig.swift — a calibration session over a scripted driver on a manual clock.
// ARCHITECTURE.md §5.2, §5.6; DESIGN.md §9.
import Foundation
import OverbrightCore
@testable import OverbrightBoost

/// One `CalibrationController` for a fixture display, with helpers that move the manual clock.
@MainActor final class CalibrationRig {
    let rig: DriverRig
    let driver: ScriptedDriver
    let controller: CalibrationController
    let key: DisplayKey
    /// Number of `onEnd` calls.
    private(set) var endings = 0
    /// The session's state when `onEnd` ran.
    private(set) var stateAtEnd: CalibrationState?

    init(_ fixture: DisplayFixture = .builtinXDRLidOpen, key: DisplayKey = DisplayFixture.Keys.builtIn,
         machine: MachineIdentity? = nil) {
        let rig = DriverRig(fixture)
        let driver = rig.driver(key) ?? rig.drivers[0]
        self.rig = rig; self.driver = driver; self.key = key
        let writer = TableWriter(gamma: rig.gamma, ledger: SafetyLedger(), time: rig.time, journal: rig.journal)
        controller = CalibrationController(display: key, driver: driver, writer: writer, time: rig.time,
                                           machine: machine ?? fixture.machine)
        controller.onEnd = { [weak self] in
            guard let self else { return }
            self.endings += 1
            self.stateAtEnd = self.controller.state
        }
    }

    /// Lets started tasks run up to their first sleep without moving the clock.
    func settle() async { for _ in 0..<20 { await Task.yield() } }

    /// Moves the clock by `duration` in 100 ms steps.
    func advance(_ duration: Duration) async {
        await settle()
        var moved = Duration.zero
        while moved < duration {
            await rig.time.advance(by: .milliseconds(100))
            moved += .milliseconds(100)
        }
    }

    /// Moves the clock until `condition` holds (at most `limit`); whether it held.
    func advance(until condition: () -> Bool, limit: Duration = .seconds(120)) async -> Bool {
        await settle()
        return await rig.advance(until: condition, limit: limit)
    }

    /// `begin()` and wait for `.ready`.
    func ready() async -> Bool {
        controller.begin()
        return await advance(until: { controller.state != .preparing })
            && controller.state == .ready
    }

    /// Starts the sweep and moves the clock until the factor reaches `factor` (or the sweep stops or pauses).
    func sweep(to factor: Double, continuingPastThePause: Bool = false) async -> Bool {
        if controller.state == .ready { controller.startSweep() }
        return await advance(until: {
            if continuingPastThePause, controller.isSweepPausedAtLimit { controller.continueSweep() }
            return controller.currentFactor >= factor - 1e-9 || controller.state != .sweeping
                || (!continuingPastThePause && controller.isSweepPausedAtLimit)
        }) && controller.currentFactor >= factor - 1e-9
    }

    /// Factor writes through the driver, in order.
    var factors: [Double] { driver.factors }
    /// Journal codes so far.
    var codes: [String] { rig.codes }
}
