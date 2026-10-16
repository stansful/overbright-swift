// OverbrightSignals/Power/PowerSourceReader.swift — the synchronous power read. ARCHITECTURE.md §3.3 (`PowerState`), §6.1
// rows 10–12, §7.1 (adapter ↔ battery, battery percent), D9, D10.
// `IOPSCopyPowerSourcesInfo` is read synchronously whenever the boost turns on (`setBoostActive(true)`), on
// `refreshPowerNow()` (master on) and on every source switch, so the reducer never sees an hours-old percentage. UPS
// power is not battery: only the providing type "Battery Power" is. The percentage comes from the internal battery's
// current and maximum capacity (Macs without a battery report none).
// Thread: any (IOKit power-source reads are thread-safe; the parsing is pure).
import Foundation
import IOKit.ps
import OverbrightCore

/// Reads and parses the power source.
nonisolated enum PowerSourceReader {
    /// The providing source (`IOPSGetProvidingPowerSourceType`): "AC Power", "Battery Power", "UPS Power".
    static func kind(providingType: String?) -> PowerSourceKind {
        switch providingType {
        case kIOPMACPowerKey?: .adapter
        case kIOPMBatteryPowerKey?: .battery
        case kIOPMUPSPowerKey?: .ups
        default: .unknown
        }
    }

    /// The internal battery's charge in percent (0…100), nil when there is none or it reports no capacity.
    static func batteryPercent(_ descriptions: [[String: Any]]) -> Int? {
        for description in descriptions where description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
            if description[kIOPSIsPresentKey] as? Bool == false { continue }
            guard let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue,
                  let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue, maximum > 0 else { continue }
            return Int((100 * current / maximum).rounded()).clamped(to: 0...100)
        }
        return nil
    }

    /// The power state from one read.
    static func state(providingType: String?, descriptions: [[String: Any]], isLowPowerMode: Bool) -> PowerState {
        PowerState(source: kind(providingType: providingType), batteryPercent: batteryPercent(descriptions),
                   isLowPowerMode: isLowPowerMode)
    }

    /// Reads the power sources now (≈ tens of microseconds; no permission).
    static func read(isLowPowerMode: Bool) -> PowerState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerState(source: .unknown, batteryPercent: nil, isLowPowerMode: isLowPowerMode)
        }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        let sources = (IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as NSArray?) as [AnyObject]? ?? []
        let descriptions = sources.compactMap { source in
            IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
        }
        return state(providingType: type, descriptions: descriptions, isLowPowerMode: isLowPowerMode)
    }
}

private extension Int {
    /// `self` limited to `range`.
    nonisolated func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
