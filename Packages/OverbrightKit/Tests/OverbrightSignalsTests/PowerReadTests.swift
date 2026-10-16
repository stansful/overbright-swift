// OverbrightSignalsTests/PowerReadTests.swift — the synchronous power read, its parsing, and when it happens.
// ARCHITECTURE.md §3.3, §6.1 rows 10–12, §7.1 (read in `setBoostActive(true)`, `refreshPowerNow()` and on every
// adapter → battery switch), D9.
import Foundation
import IOKit.ps
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct PowerReadTests {
    private let internalBattery: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 64, "Max Capacity": 100,
                                                  "Is Present": true, "Power Source State": "Battery Power"]

    @Test func providingTypesMapToSources() {
        #expect(PowerSourceReader.kind(providingType: "AC Power") == .adapter)
        #expect(PowerSourceReader.kind(providingType: "Battery Power") == .battery)
        #expect(PowerSourceReader.kind(providingType: "UPS Power") == .ups)                // UPS is not battery
        #expect(PowerSourceReader.kind(providingType: nil) == .unknown)
        #expect(PowerSourceReader.kind(providingType: "Off Line") == .unknown)
    }

    @Test func theKeysAreIOKitsOwn() {
        #expect(kIOPSTypeKey == "Type" && kIOPSInternalBatteryType == "InternalBattery")
        #expect(kIOPSCurrentCapacityKey == "Current Capacity" && kIOPSMaxCapacityKey == "Max Capacity")
        #expect(kIOPMACPowerKey == "AC Power" && kIOPMBatteryPowerKey == "Battery Power")
    }

    @Test func aMacBookOnBatteryReportsItsPercent() {
        let state = PowerSourceReader.state(providingType: "Battery Power", descriptions: [internalBattery],
                                            isLowPowerMode: true)
        #expect(state == PowerState(source: .battery, batteryPercent: 64, isLowPowerMode: true))
    }

    @Test func thePercentIsRoundedFromCapacities() {
        var battery = internalBattery
        battery["Current Capacity"] = 4321
        battery["Max Capacity"] = 5000
        #expect(PowerSourceReader.batteryPercent([battery]) == 86)
        battery["Max Capacity"] = 0
        #expect(PowerSourceReader.batteryPercent([battery]) == nil)
    }

    @Test func desktopsAndAbsentOrForeignBatteriesHaveNoPercent() {
        #expect(PowerSourceReader.batteryPercent([]) == nil)
        var absent = internalBattery
        absent["Is Present"] = false
        #expect(PowerSourceReader.batteryPercent([absent]) == nil)
        var ups = internalBattery
        ups["Type"] = "UPS"
        #expect(PowerSourceReader.batteryPercent([ups]) == nil)
        let desktop = PowerSourceReader.state(providingType: "AC Power", descriptions: [], isLowPowerMode: false)
        #expect(desktop == PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: false))
    }

    @Test func theThermalStatesMapInOrder() {
        #expect(ThermalLevel(ProcessInfo.ThermalState.nominal) == .nominal)
        #expect(ThermalLevel(ProcessInfo.ThermalState.fair) == .fair)
        #expect(ThermalLevel(ProcessInfo.ThermalState.serious) == .serious)
        #expect(ThermalLevel(ProcessInfo.ThermalState.critical) == .critical)
    }

    @Test func theLiveReadAnswersWithoutPermission() {
        let state = PowerSourceReader.read(isLowPowerMode: false)
        #expect(state.batteryPercent.map { (0...100).contains($0) } ?? true)
    }

    // MARK: When the monitor reads

    @MainActor @Test func boostActiveReadsSynchronouslyWithoutAnEvent() async {
        let harness = SignalsHarness()
        await harness.start()
        var events: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { events.append($0) }
        harness.platform.power = PowerState(source: .battery, batteryPercent: 18, isLowPowerMode: false)
        let reads = harness.platform.powerReads
        harness.monitor.setBoostActive(true)
        #expect(harness.platform.powerReads == reads + 1)
        #expect(harness.monitor.snapshot.power.batteryPercent == 18)      // fresh before the engine reduces
        #expect(events.isEmpty)
        harness.platform.power.batteryPercent = 17
        harness.monitor.refreshPowerNow()
        #expect(harness.monitor.snapshot.power.batteryPercent == 17 && events.isEmpty)
        token.cancel()
    }

    @MainActor @Test func anAdapterToBatterySwitchReadsAtOnceAndStartsThePercentSource() async {
        let harness = SignalsHarness()
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(harness.platform.batterySources == 0)                       // on the adapter: no percent source
        var events: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { events.append($0) }
        harness.platform.switchPowerSource(to: PowerState(source: .battery, batteryPercent: 64, isLowPowerMode: false))
        #expect(harness.monitor.snapshot.power == PowerState(source: .battery, batteryPercent: 64, isLowPowerMode: false))
        #expect(events == [.powerChanged])
        #expect(harness.platform.batterySources == 1)
        harness.platform.changeBattery(to: PowerState(source: .battery, batteryPercent: 63, isLowPowerMode: false))
        #expect(harness.monitor.snapshot.power.batteryPercent == 63 && events == [.powerChanged, .powerChanged])
        harness.platform.switchPowerSource(to: PowerState(source: .adapter, batteryPercent: 63, isLowPowerMode: false))
        #expect(harness.platform.batterySources == 0)                       // back on the adapter: stopped
        #expect(events.count == 3)
        token.cancel()
    }

    @MainActor @Test func anUnchangedReadPostsNothing() async {
        let harness = SignalsHarness()
        await harness.start()
        var events: [SystemEvent] = []
        let token = harness.monitor.addEventObserver { events.append($0) }
        harness.platform.switchPowerSource(to: harness.platform.power)
        #expect(events.isEmpty)
        token.cancel()
    }
}
