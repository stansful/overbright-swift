// OverbrightCore/Model/Policy/PolicyInput.swift — everything the pure reducer needs. ARCHITECTURE.md §3.4, §6, D10.
import Foundation

/// Everything the pure reducer needs. Building it is the engine's job; deciding is Policy's.
public nonisolated struct PolicyInput: Hashable, Sendable {
    /// The master switch.
    public var isMasterOn: Bool
    /// "Pause for…" deadline (wall clock); nil when not paused.
    public var pausedUntil: Date?
    /// The wall clock now.
    public var now: Date
    /// Local minute of day for the schedule (the engine computes it with the current calendar and time zone).
    public var minuteOfDay: Int
    /// Model and OS: the compatibility-model list and calibration validity (`CompatibilityModels`, §5.2).
    public var machine: MachineIdentity
    /// The flattened settings.
    public var settings: PolicySettings
    /// The system snapshot.
    public var system: SystemSnapshot
    /// One entry per online display.
    public var displays: [DisplayPolicyInput]
    /// Conflict entries the user chose to continue with in this session (cleared at relaunch).
    public var continuedEntryIDs: Set<String>
    /// The reducer's input.
    public init(isMasterOn: Bool, pausedUntil: Date?, now: Date, minuteOfDay: Int, machine: MachineIdentity,
                settings: PolicySettings, system: SystemSnapshot, displays: [DisplayPolicyInput],
                continuedEntryIDs: Set<String>) {
        self.isMasterOn = isMasterOn; self.pausedUntil = pausedUntil; self.now = now; self.minuteOfDay = minuteOfDay
        self.machine = machine; self.settings = settings; self.system = system; self.displays = displays
        self.continuedEntryIDs = continuedEntryIDs
    }
}
