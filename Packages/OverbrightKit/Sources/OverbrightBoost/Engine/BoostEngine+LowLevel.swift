// OverbrightBoost/Engine/BoostEngine+LowLevel.swift — "Keep this level?": every level change a person makes away from
// Standard asks on the display whose control moved, and so does turning on with a level away from Standard; without an
// answer the display goes back to Standard after 10 s (the owner's rule, 2026-10-20). ARCHITECTURE.md §3.6, §4.9;
// DESIGN.md §6.
// MainActor.
import Foundation
import OverbrightCore

extension BoostEngine {
    /// Sources whose level changes ask "Keep this level?": every way a person moves a display's level.
    static let keepPromptSources: Set<ControlSource> = [.panel, .menu, .shortcut, .intent, .settings]

    /// Sources whose turning on asks when a stored level is away from Standard: every way a person turns Overbright
    /// on (a login launch with "turn on", the status item's toggle, Welcome and Focus included), so a panel that turns
    /// white comes back by itself whichever way the boost began. Automations only resume a level that was already on
    /// screen, so they never ask.
    static let turnOnPromptSources: Set<ControlSource> = keepPromptSources.union([.focusFilter, .welcome, .launch,
                                                                                  .statusItem])

    /// Confirms the pending level.
    public func keepLowLevel() {
        guard let pending = pendingLowLevel else { return }
        pendingLowLevel = nil
        lowLevelSlot.cancel()
        journal.record("lowLevel.kept", display: pending.display, time: time)
        publish()
    }

    /// Returns the displays of the pending question to Standard.
    public func revertLowLevel() {
        guard pendingLowLevel != nil else { return }
        restoreLowLevel()
        reduceNow()
    }

    /// The owner's rule (2026-10-20): every change a person makes to a display's level away from Standard asks "Keep
    /// this level?" on that display, and the display goes back to **Standard** after 10 s without an answer. How a
    /// scaled table looks depends on each panel and macOS release and software cannot see it, so a screen that turns
    /// white or dark always comes back by itself. A drag is one change: while the level keeps moving, the 10 s start
    /// again from the last step. A change back to Standard ends the question for that display. `display` is the
    /// display whose control moved (nil: every display).
    func askToKeep(priorStored: [DisplayKey: LevelPosition], source: ControlSource, display: DisplayKey?) {
        guard keepPromptEnabled, Self.keepPromptSources.contains(source), isMasterOn else { return }
        let changed = priorStored.keys.filter { storedLevel(of: $0) != priorStored[$0] }
        guard !changed.isEmpty else { return }
        var revertTo = pendingLowLevel?.previousLevels ?? [:]
        for key in changed { revertTo[key] = storedLevel(of: key) == .standard ? nil : .standard }
        guard !revertTo.isEmpty else {
            if let pending = pendingLowLevel {
                pendingLowLevel = nil
                lowLevelSlot.cancel()
                journal.record("keep.ended", display: pending.display, time: time)
            }
            return
        }
        let shown = display ?? (revertTo.count == 1 ? revertTo.keys.first : pendingLowLevel?.display)
        pendingLowLevel = LowLevelConfirmation(display: shown, previousLevels: revertTo,
                                               deadline: time.wallClock + EngineTiming.lowLevelConfirmTimeout.timeInterval)
        journal.record("keep.asked", display: shown, time: time)
        armConfirmationRevert()
    }

    /// Turning Overbright on with a level away from Standard asks too (the same rule, the master as the change).
    func askToKeepAfterTurningOn(source: ControlSource) {
        guard keepPromptEnabled, Self.turnOnPromptSources.contains(source), isMasterOn else { return }
        let keys = displays.displays.map(\.ref.key).filter { storedLevel(of: $0) != .standard }
        guard !keys.isEmpty else { return }
        let revertTo = Self.byKey(keys.map { ($0, LevelPosition.standard) })
        let shown = keys.count == 1 ? keys.first : nil
        pendingLowLevel = LowLevelConfirmation(display: shown, previousLevels: revertTo,
                                               deadline: time.wallClock + EngineTiming.lowLevelConfirmTimeout.timeInterval)
        journal.record("keep.asked", display: shown, time: time)
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

    /// The 10 s revert of the pending confirmation (§4.9).
    private func armConfirmationRevert() {
        lowLevelSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.lowLevelConfirmTimeout) } catch { return }
            guard let pending = self.pendingLowLevel else { return }
            self.journal.record("lowLevel.reverted", display: pending.display, time: self.time)
            self.restoreLowLevel()
            self.reduceNow()
        }
    }
}
