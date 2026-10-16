// OverbrightBoostTests/SelfTest/ScriptedDriver.swift — a `DisplayControllerDriving` over the Core fakes, standing in
// for WP4's `DisplayController` in the self-test and calibration suites (ARCHITECTURE.md §4.1, §8.4; DESIGN.md §9).
// Arming makes a trigger with `FakeTriggerFactory`, so `ScriptedHeadroom` grants headroom as scripted; factor writes
// multiply the baseline into `FakeGammaPort`, refusing anything above `maxFactor` as `TableWriter` does.
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightBoost

/// One display driven by the self-test or the calibration, with every call recorded.
@MainActor final class ScriptedDriver: DisplayControllerDriving {
    /// A recorded call.
    enum Call: Hashable {
        case arm(TriggerStrategy, TriggerPixel)
        case disarm
        case returnToStandard
        case factor(Double, max: Double)
    }

    let display: DisplayRef
    let gamma: FakeGammaPort
    let headroom: ScriptedHeadroom
    let factory: FakeTriggerFactory
    let baseline: GammaTable
    private(set) var calls: [Call] = []
    /// The factor on screen (1 = the baseline).
    private(set) var factor = 1.0
    /// Every factor written, in order.
    var factors: [Double] { calls.compactMap { if case .factor(let f, _) = $0 { f } else { nil } } }
    /// Refuse factor writes (the interlock refused: stale reading, hang epoch).
    var refusesFactors = false
    private var trigger: (any TriggerHandle)?

    init(display: DisplayRef, gamma: FakeGammaPort, headroom: ScriptedHeadroom, factory: FakeTriggerFactory,
         baseline: GammaTable) {
        self.display = display; self.gamma = gamma; self.headroom = headroom; self.factory = factory
        self.baseline = baseline
    }

    /// Whether a trigger is shown.
    var isArmed: Bool { trigger != nil }

    func arm(rung: TriggerRequest) async -> Bool {
        calls.append(.arm(rung.strategy, rung.pixel))
        trigger?.remove()
        trigger = nil
        guard let handle = try? factory.makeTrigger(rung, on: display) else { return false }
        trigger = handle
        return await handle.present(rung.pixel)
    }

    func readHeadroom() -> HeadroomReading? { headroom.reading(for: display) }

    func disarm() async {
        calls.append(.disarm)
        writeBaseline()
        trigger?.remove()
        trigger = nil
    }

    func returnToStandard() {
        calls.append(.returnToStandard)
        writeBaseline()
        trigger?.remove()
        trigger = nil
    }

    func writeCalibrationFactor(_ factor: Double, maxFactor: Double) throws {
        calls.append(.factor(factor, max: maxFactor))
        guard !refusesFactors, factor <= maxFactor + 1e-9 else { throw GammaError.writeRefused }
        try gamma.write(baseline.scaled(by: Float(factor)), to: display.id)
        self.factor = factor
    }

    private func writeBaseline() {
        try? gamma.write(baseline, to: display.id)
        factor = 1
    }
}

/// The fakes of one fixture on a manual clock, with a driver per display.
@MainActor final class DriverRig {
    let time: ManualTimeSource
    let fixture: DisplayFixture
    let gamma: FakeGammaPort
    let headroom: ScriptedHeadroom
    let factory: FakeTriggerFactory
    let journal = RingBufferJournal()
    let drivers: [ScriptedDriver]

    init(_ fixture: DisplayFixture = .builtinXDRLidOpen) {
        self.fixture = fixture
        let time = ManualTimeSource()
        self.time = time
        let gamma = FakeGammaPort(fixture: fixture, time: time)
        let headroom = ScriptedHeadroom(fixture: fixture, time: time)
        let factory = FakeTriggerFactory(headroom: headroom)
        self.gamma = gamma; self.headroom = headroom; self.factory = factory
        drivers = fixture.displays.compactMap { display in
            display.profileBase.map { base in
                ScriptedDriver(display: display.facts.ref, gamma: gamma, headroom: headroom, factory: factory,
                               baseline: base)
            }
        }
    }

    /// The driver of `key`.
    func driver(_ key: DisplayKey = DisplayFixture.Keys.builtIn) -> ScriptedDriver? {
        drivers.first { $0.display.key == key }
    }

    /// Moves the manual clock in 100 ms steps until `done` holds (at most `limit`), running `each` after every step.
    func advance(until done: () -> Bool, limit: Duration = .seconds(900), each: (Duration) -> Void = { _ in })
        async -> Bool {
        var elapsed = Duration.zero
        while !done() {
            guard elapsed < limit else { return false }
            await time.advance(by: .milliseconds(100))
            elapsed += .milliseconds(100)
            each(elapsed)
        }
        return true
    }

    /// Journal codes so far.
    var codes: [String] { journal.snapshot().map(\.code) }
}
