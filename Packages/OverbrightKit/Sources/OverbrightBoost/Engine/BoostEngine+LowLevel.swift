// OverbrightBoost/Engine/BoostEngine+LowLevel.swift — "Keep this level?": a level change that takes a display below
// 10 % of Standard light asks, and so does a display's first boost on a macOS build; both revert by themselves after
// 10 s unless kept. ARCHITECTURE.md §3.6, §4.9; DESIGN.md §6.
// MainActor.
import Foundation
import OverbrightCore

extension BoostEngine {
    /// Sources whose level changes ask "Keep this level?" below 10 % of Standard light, or on a first boost
    /// (DESIGN.md §6).
    static let lowLevelSources: Set<ControlSource> = [.panel, .menu, .shortcut, .intent]

    /// Confirms the pending level; a first boost records the running macOS build for its displays, so they do not
    /// ask again until macOS changes.
    public func keepLowLevel() {
        guard let pending = pendingLowLevel else { return }
        pendingLowLevel = nil
        lowLevelSlot.cancel()
        recordBoostConfirmed(pending.firstBoostDisplays)
        journal.record(pending.firstBoostDisplays.isEmpty ? "lowLevel.kept" : "firstBoost.kept",
                       display: pending.display, time: time)
        publish()
    }

    /// Returns to the levels before the pending change.
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
        armConfirmationRevert()
    }

    /// "Keep this level?" when a change from the panel, the menu, a shortcut or an intent starts a boost on a display
    /// whose boost nobody has kept on this macOS build (§4.9). How a table above 1 looks depends on the display
    /// pipeline of each panel and macOS release, and software cannot see it: a display that turns white (or dark)
    /// instead of brighter must come back by itself, without anyone reading the prompt. Unanswered, the engine
    /// returns those displays to Standard after 10 s. `wasBoosting` says which displays boosted before the change.
    func checkFirstBoost(priorStored: [DisplayKey: LevelPosition], wasBoosting: [DisplayKey: Bool],
                         source: ControlSource) {
        if let pending = pendingLowLevel, !pending.firstBoostDisplays.isEmpty,
           !pending.firstBoostDisplays.contains(where: { isMasterOn && storedLevel(of: $0).isBoost }) {
            // The boost it asked about has ended: nothing is left to keep or revert.
            pendingLowLevel = nil
            lowLevelSlot.cancel()
            journal.record("firstBoost.ended", display: pending.display, time: time)
            return
        }
        guard Self.lowLevelSources.contains(source), pendingLowLevel == nil, isMasterOn else { return }
        let build = machine.osBuild
        let preferences = settings[DisplaySettings.perDisplay]
        let fresh = priorStored.keys.filter { key in
            !(wasBoosting[key] ?? false) && storedLevel(of: key).isBoost && canBoost(key)
                && preferences[key]?.boostConfirmedBuild != build
        }.sorted()
        guard !fresh.isEmpty else { return }
        // Linked, one level serves every display (`restoreLowLevel` writes one of these back), so every boost goes.
        let linked = settings[DisplaySettings.linkLevels]
        var previous = priorStored
        for key in priorStored.keys where (linked || fresh.contains(key)) && (priorStored[key]?.isBoost ?? true) {
            previous[key] = .standard
        }
        pendingLowLevel = LowLevelConfirmation(display: fresh.count == 1 ? fresh.first : nil,
                                               previousLevels: previous,
                                               deadline: time.wallClock + EngineTiming.lowLevelConfirmTimeout.timeInterval,
                                               firstBoostDisplays: fresh)
        journal.record("firstBoost.asked", display: fresh.count == 1 ? fresh.first : nil, time: time)
        armConfirmationRevert()
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

    // MARK: Internals

    /// The 10 s revert of the pending confirmation (§4.9); one slot for both kinds.
    private func armConfirmationRevert() {
        lowLevelSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.lowLevelConfirmTimeout) } catch { return }
            guard let pending = self.pendingLowLevel else { return }
            self.journal.record(pending.firstBoostDisplays.isEmpty ? "lowLevel.reverted" : "firstBoost.reverted",
                                display: pending.display, time: self.time)
            self.restoreLowLevel()
            self.reduceNow()
        }
    }

    /// Whether `key` can boost by the last decision (unknown or still checking counts as yes: the prompt is cheap).
    private func canBoost(_ key: DisplayKey) -> Bool {
        guard let verdict = lastDecision?.displays[key]?.eligibility.verdict, verdict != .checking else { return true }
        return verdict.allowsBoost
    }

    /// Records the running macOS build as kept for `keys`.
    private func recordBoostConfirmed(_ keys: [DisplayKey]) {
        guard !keys.isEmpty else { return }
        var all = settings[DisplaySettings.perDisplay]
        for key in keys {
            var preferences = all[key] ?? DisplayPreferences()
            preferences.boostConfirmedBuild = machine.osBuild
            all[key] = preferences
        }
        settings[DisplaySettings.perDisplay] = all
    }
}
