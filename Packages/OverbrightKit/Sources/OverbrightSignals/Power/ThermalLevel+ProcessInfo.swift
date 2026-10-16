// OverbrightSignals/Power/ThermalLevel+ProcessInfo.swift — Foundation's thermal state as Core's `ThermalLevel`.
// ARCHITECTURE.md §3.3, §6.1 (serious caps, critical stops), §7.1 ("Thermal").
// Thread: any (pure).
import Foundation
import OverbrightCore

extension ThermalLevel {
    /// The level for `ProcessInfo.ThermalState` (an unknown future state counts as `.fair`, never as a stop).
    nonisolated init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .fair
        }
    }
}
