// OverbrightAppShellTests/Support/TrapPorts.swift — ports that record every call, for
// `constructingServicesTouchesNoHardware` and `diagnosticsNeverWrites` (ARCHITECTURE.md §3.9, §8.4, §9.1). A recorded
// call before `start()` is a failure: constructing the services must do no I/O, hardware or network access.
import CoreGraphics
import Foundation
import Observation
import OverbrightCore
import ServiceManagement
@testable import OverbrightAppShell

/// Every call any trap port received, in order.
final class TrapLog {
    private(set) var calls: [String] = []
    func record(_ call: String) { calls.append(call) }
}

/// A `GammaPort` that records reads and writes separately; reads are answered by `reads` (or as a display without a
/// table), writes always throw. Lock-protected like the real port.
nonisolated final class TrapGammaPort: GammaPort, @unchecked Sendable {
    private let lock = NSLock()
    private let forward: FakeGammaPort?
    private var readCalls: [String] = []
    private var writeCalls: [String] = []

    /// A trap answering reads from `reads`.
    init(forwardingReadsTo reads: FakeGammaPort? = nil) { forward = reads }

    /// Every read (`capacity`, `read`, `profileBase`, `writeCount`).
    var reads: [String] { lock.withLock { readCalls } }
    /// Every write and restore.
    var writes: [String] { lock.withLock { writeCalls } }

    func capacity(of display: CGDirectDisplayID) -> Int {
        lock.withLock { readCalls.append("capacity(\(display))") }
        return forward?.capacity(of: display) ?? 0
    }
    func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        lock.withLock { readCalls.append("read(\(display))") }
        guard let forward else { throw GammaError.noTable }
        return try forward.read(display)
    }
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        lock.withLock { readCalls.append("profileBase(\(display))") }
        return forward?.profileBase(of: display, count: count) ?? .identity(count: count)
    }
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {
        lock.withLock { writeCalls.append("write(\(display))") }
        throw GammaError.writeRefused
    }
    func restoreSystemColorSettings() { lock.withLock { writeCalls.append("restoreSystemColorSettings") } }
    var writeCount: Int {
        lock.withLock { readCalls.append("writeCount") }
        return forward?.writeCount ?? 0
    }
}

/// A `HeadroomPort` that records every reading.
final class TrapHeadroom: HeadroomPort {
    let log: TrapLog
    init(log: TrapLog) { self.log = log }
    func reading(for display: DisplayRef) -> HeadroomReading? { log.record("headroom.reading"); return nil }
}

/// A `DisplayDirectory` that records every read.
@Observable final class TrapDisplayDirectory: DisplayDirectory {
    @ObservationIgnored let log: TrapLog
    init(log: TrapLog) { self.log = log }
    var displays: [DisplayFacts] { log.record("directory.displays"); return [] }
    var generation: Int { log.record("directory.generation"); return 0 }
    func facts(for key: DisplayKey) -> DisplayFacts? { log.record("directory.facts"); return nil }
}

/// A `TriggerFactory` that records every call and never makes a window.
final class TrapTriggerFactory: TriggerFactory {
    let log: TrapLog
    init(log: TrapLog) { self.log = log }
    func isAvailable(_ strategy: TriggerStrategy) -> Bool { log.record("triggers.isAvailable"); return false }
    func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle {
        log.record("triggers.makeTrigger")
        throw TriggerError.displayGone
    }
    func makeOverlay(on display: DisplayRef) throws -> any OverlayHandle {
        log.record("triggers.makeOverlay")
        throw TriggerError.displayGone
    }
    var openWindowCount: Int { log.record("triggers.openWindowCount"); return 0 }
}

/// `SystemSignals` that record every call.
@Observable final class TrapSignals: SystemSignals {
    @ObservationIgnored let log: TrapLog
    init(log: TrapLog) { self.log = log }
    var snapshot: SystemSnapshot {
        log.record("signals.snapshot")
        return SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: false))
    }
    func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        log.record("signals.addEventObserver")
        return ObservationToken {}
    }
    func setBoostActive(_ active: Bool) { log.record("signals.setBoostActive") }
    func refreshPowerNow() { log.record("signals.refreshPowerNow") }
    func setFocusDirective(_ directive: FocusDirective) { log.record("signals.setFocusDirective") }
}

/// A `ConflictProbe` that records every call.
final class TrapConflictProbe: ConflictProbe {
    let log: TrapLog
    init(log: TrapLog) { self.log = log }
    func runningConflicts() -> [ConflictingApp] { log.record("conflicts.running"); return [] }
    func attributeDrift() async -> ConflictingApp? { log.record("conflicts.attributeDrift"); return nil }
}

/// A `FillLightControl` that records every call.
@Observable final class TrapFillLight: FillLightControl {
    @ObservationIgnored let log: TrapLog
    init(log: TrapLog) { self.log = log }
    var isOn: Bool { log.record("fillLight.isOn"); return false }
    var isAutomatic: Bool { log.record("fillLight.isAutomatic"); return false }
    func setOn(_ on: Bool, source: ControlSource) { log.record("fillLight.setOn") }
}

/// A `ShortcutCenter` that records every call (registering a hot key is system state).
@Observable final class TrapShortcuts: ShortcutCenter {
    @ObservationIgnored let log: TrapLog
    init(log: TrapLog) { self.log = log }
    func state(_ id: ShortcutID) -> ShortcutState { log.record("shortcuts.state"); return .off }
    func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState { log.record("shortcuts.set"); return .off }
    func setRecording(_ recording: Bool) { log.record("shortcuts.setRecording") }
    func displayString(_ id: ShortcutID) -> String? { log.record("shortcuts.displayString"); return nil }
}

/// An `UpdateChecking` that records every call (a check is network access).
@Observable final class TrapUpdates: UpdateChecking {
    @ObservationIgnored let log: TrapLog
    init(log: TrapLog) { self.log = log }
    var isConfigured: Bool { log.record("updates.isConfigured"); return false }
    var state: UpdateState { log.record("updates.state"); return .idle }
    func checkNow() { log.record("updates.checkNow") }
}

/// A login item that records every call (registering one is system state).
final class TrapLoginItem: LoginItemService {
    let log: TrapLog
    init(log: TrapLog) { self.log = log }
    var status: SMAppService.Status { log.record("loginItem.status"); return .notRegistered }
    func register() throws { log.record("loginItem.register") }
    func unregister() throws { log.record("loginItem.unregister") }
    func openSystemSettingsLoginItems() { log.record("loginItem.openSystemSettings") }
}

extension ShellPorts {
    /// Every port a trap recording into `log` (gamma calls go to `gamma`); no service has a lifecycle of its own.
    static func traps(log: TrapLog, gamma: TrapGammaPort) -> ShellPorts {
        let signals = TrapSignals(log: log)
        return ShellPorts(gamma: gamma, headroom: TrapHeadroom(log: log), displays: TrapDisplayDirectory(log: log),
                          triggers: TrapTriggerFactory(log: log), signals: signals, launchCheckSignals: signals,
                          conflicts: TrapConflictProbe(log: log), fillLight: TrapFillLight(log: log),
                          shortcuts: TrapShortcuts(log: log), hotKeys: nil, updates: TrapUpdates(log: log),
                          loginItems: TrapLoginItem(log: log), controlOutlet: QuietControlOutlet(),
                          readDisplays: { log.record("readDisplays"); return [] },
                          profileHasVCGT: { _ in log.record("profileHasVCGT"); return nil },
                          backlightMilliNits: { log.record("backlightMilliNits"); return nil },
                          services: ServiceStack(), relays: [], fixture: nil)
    }
}
