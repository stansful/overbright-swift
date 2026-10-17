// OverbrightBoost/Engine/BoostEngine+LowLevel.swift — "Keep this level?": a level change that takes a display below
// 10 % of Standard light asks, and reverts by itself after 10 s unless kept. ARCHITECTURE.md §3.6, §4.9; DESIGN.md §6.
// MainActor.
import Foundation
import OverbrightCore

extension BoostEngine {
    /// Sources whose level changes ask "Keep this level?" below 10 % of Standard light (DESIGN.md §6).
    static let lowLevelSources: Set<ControlSource> = [.panel, .menu, .shortcut, .intent]

    /// Confirms the very dark level.
    public func keepLowLevel() {
        guard pendingLowLevel != nil else { return }
        pendingLowLevel = nil
        lowLevelSlot.cancel()
        journal.record("lowLevel.kept", display: nil, time: time)
        publish()
    }

    /// Returns to the levels before the very dark change.
    public func revertLowLevel() {
        guard pendingLowLevel != nil else { return }
        restoreLowLevel()
        reduceNow()
    }

    /// "Keep this level?" when a change from the panel, the menu, a shortcut or an intent takes a display from at
    /// least 10 % to below 10 % of Standard light; the engine reverts by itself after 10 s (§4.9).
    func checkLowLevel(priorStored: [DisplayKey: LevelPosition], priorLight: [DisplayKey: Double],
                       source: ControlSource) {
        guard Self.lowLevelSources.contains(source) else { return }
        let crossed = priorLight.keys.filter { key in
            (priorLight[key] ?? 1) >= EngineTiming.lowLevelThreshold
                && light(of: storedLevel(of: key)) < EngineTiming.lowLevelThreshold
        }.sorted()
        guard !crossed.isEmpty else { return }
        let previous = pendingLowLevel?.previousLevels ?? priorStored
        pendingLowLevel = LowLevelConfirmation(display: crossed.count == 1 ? crossed.first : nil,
                                               previousLevels: previous,
                                               deadline: time.wallClock + EngineTiming.lowLevelConfirmTimeout.timeInterval)
        journal.record("lowLevel.asked", display: crossed.count == 1 ? crossed.first : nil, time: time)
        lowLevelSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.lowLevelConfirmTimeout) } catch { return }
            guard self.pendingLowLevel != nil else { return }
            self.journal.record("lowLevel.reverted", display: nil, time: self.time)
            self.restoreLowLevel()
            self.reduceNow()
        }
    }

    /// Writes the levels of the pending confirmation back and forgets it.
    func restoreLowLevel() {
        guard let pending = pendingLowLevel else { return }
        pendingLowLevel = nil
        lowLevelSlot.cancel()
        if settings[DisplaySettings.linkLevels] {
            if let level = pending.previousLevels.values.first { settings[DisplaySettings.linkedLevel] = level }
        } else {
            var all = settings[DisplaySettings.perDisplay]
            for (key, level) in pending.previousLevels {
                var preferences = all[key] ?? DisplayPreferences()
                preferences.level = level
                all[key] = preferences
            }
            settings[DisplaySettings.perDisplay] = all
        }
    }
}
