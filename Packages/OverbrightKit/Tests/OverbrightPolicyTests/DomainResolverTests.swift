// OverbrightPolicyTests/DomainResolverTests.swift — the transfer domain actually used, and the compatibility models
// that made the reducer default to the overlay (unused while Compatibility mode is disabled). ARCHITECTURE.md §5.2,
// §6.1 steps 4–5, §7.5.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct DomainResolverTests {
    private let machine = DisplayFixture.ownerMachine
    private func record(_ outcome: CalibrationRecord.Outcome, mechanism: Mechanism = .table, build: String = "26A434",
                        potential: Double = 16) -> CalibrationRecord {
        CalibrationRecord(outcome: outcome, mechanism: mechanism, mergeFactor: 3.0, estimatedExponent: 1.0,
                          measuredSDRWhiteNits: nil, headroomAtTest: 2.667, potentialAtTest: potential, osBuild: build,
                          measuredAt: Date(timeIntervalSinceReferenceDate: 0))
    }
    private func domain(_ r: CalibrationRecord?, _ mechanism: Mechanism = .table, potential: Double? = 16) -> TransferDomain {
        TransferDomainResolver.effectiveDomain(r, mechanism: mechanism, machine: machine, potential: potential)
    }

    /// `.linear` only from a confirmed linear record for this mechanism, OS build and potential (±5 %).
    @Test func linearNeedsAValidConfirmedRecord() {
        #expect(domain(record(.linear)) == .linear)
        #expect(domain(record(.linear), potential: 16.79) == .linear && domain(record(.linear), potential: 15.21) == .linear)
        #expect(domain(record(.linear), potential: 16.9) == .encoded && domain(record(.linear), potential: 15.1) == .encoded)
        #expect(domain(record(.linear), potential: nil) == .encoded)
        #expect(domain(record(.linear, build: "26A123")) == .encoded)              // another OS build
        #expect(domain(record(.linear), .overlay) == .encoded)                     // another mechanism
        #expect(domain(record(.linear, mechanism: .overlay), .overlay) == .linear)
        for outcome: CalibrationRecord.Outcome in [.encoded, .inconclusive, .notBrighter] {
            #expect(domain(record(outcome)) == .encoded)
        }
        #expect(domain(nil) == .encoded)
    }

    @Test func tableWritesAreIgnoredOnTheListedModelsFrom26Point3() {
        func machine(_ model: String, _ major: Int, _ minor: Int) -> MachineIdentity {
            MachineIdentity(model: model, osBuild: "x", osMajor: major, osMinor: minor, osPatch: 0)
        }
        #expect(CompatibilityModels.tableWritesIgnored(DisplayFixture.neoIgnoresWrites.machine))
        for model in ["Mac17,5", "Mac17,6", "Mac17,7", "Mac17,8", "Mac17,9"] {
            #expect(CompatibilityModels.tableWritesIgnored(machine(model, 26, 3)), "\(model)")
            #expect(CompatibilityModels.tableWritesIgnored(machine(model, 27, 0)), "\(model)")
            #expect(!CompatibilityModels.tableWritesIgnored(machine(model, 26, 2)), "\(model)")
        }
        #expect(!CompatibilityModels.tableWritesIgnored(DisplayFixture.ownerMachine))
        #expect(!CompatibilityModels.tableWritesIgnored(machine("Mac17,10", 27, 0)))
    }

    /// The reducer hands the engine the resolved domain: `.linear` only for a valid linear record of the display's
    /// mechanism, `.encoded` once the OS build, the potential or the mechanism changes.
    @Test func theReducerResolvesTheDomainPerDisplay() {
        func decided(_ record: CalibrationRecord?, mechanism: MechanismPreference = .automatic,
                     potential: Double = 16) -> DisplayDecision? {
            let reading = PolicyTestInputs.reading(PolicyTestInputs.builtIn, potential: potential)
            let display = PolicyTestInputs.display(mechanism: mechanism, calibration: record, reading: reading)
            return BoostPolicy.reduce(PolicyTestInputs.input([display])).builtIn
        }
        #expect(decided(record(.linear))?.domain == .linear)
        #expect(decided(record(.linear), potential: 6)?.domain == .encoded)                  // preset changed
        #expect(decided(record(.linear, build: "26A123"))?.domain == .encoded)               // macOS updated
        // Compatibility mode is unavailable (§7.5): a stored overlay preference uses the table, so a table record applies.
        #expect(decided(record(.linear), mechanism: .overlay)?.domain == .linear)
        #expect(decided(record(.linear, mechanism: .overlay), mechanism: .overlay)?.domain == .encoded)  // other mechanism
        #expect(decided(record(.inconclusive))?.domain == .encoded && decided(nil)?.domain == .encoded)
        // On a compatibility model the automatic mechanism is the table too, so its table record still applies.
        let neo = DisplayFixture.neoIgnoresWrites
        let calibration = record(.linear, build: neo.machine.osBuild)
        let display = PolicyTestInputs.display(neo.displays[0], calibration: calibration)
        let decision = BoostPolicy.reduce(PolicyTestInputs.input([display], machine: neo.machine)).builtIn
        #expect(decision?.mechanism == .table)
        #expect(decision?.domain == TransferDomainResolver.effectiveDomain(
            calibration, mechanism: .table, machine: neo.machine, potential: neo.displays[0].headroom.potential))
    }
}
