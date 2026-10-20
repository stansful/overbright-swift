// OverbrightBoost/Engine/BoostEngine+LevelConfirmation.swift — "Keep this level?": a level change a person makes
// away from Standard asks on the display whose control moved, and so does turning on with a level away from Standard;
// without an answer the display goes back to Standard after 10 s (the owner's rule, 2026-10-20). Levels inside the
// range already kept on that display, macOS build and winning rung do not ask again (2026-10-21).
// ARCHITECTURE.md §3.6, §4.9; DESIGN.md §6. MainActor.
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

    /// Confirms the pending level, and widens each asked display's kept range to take its level in.
    public func keepLevel() {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        confirmationSlot.cancel()
        widenKeptRanges(pending.previousLevels.keys)
        journal.record("keep.kept", display: pending.display, time: time)
        publish()
    }

    /// Returns the displays of the pending question to Standard.
    public func revertLevel() {
        guard pendingConfirmation != nil else { return }
        restorePreviousLevels()
        reduceNow()
    }

    /// The owner's rule (2026-10-20): a change a person makes to a display's level away from Standard asks "Keep this
    /// level?" on that display, and the display goes back to **Standard** after 10 s without an answer. How a scaled
    /// table looks depends on each panel, macOS release and trigger and software cannot see it, so a screen that turns
    /// white or dark always comes back by itself. A level inside the range already kept on that display (`keptRange`)
    /// asks nothing. A drag is one change: while the level keeps moving beyond the range, the 10 s start again from
    /// the last step. A change back to Standard or into the kept range ends the question for that display. `display`
    /// is the display whose control moved (nil: every display).
    func askToKeep(priorStored: [DisplayKey: LevelPosition], source: ControlSource, display: DisplayKey?) {
        guard keepPromptEnabled, Self.keepPromptSources.contains(source), isMasterOn else { return }
        let changed = priorStored.keys.filter { storedLevel(of: $0) != priorStored[$0] }
        guard !changed.isEmpty else { return }
        let asking = changed.filter { !isKept(storedLevel(of: $0), on: $0) }
        var revertTo = pendingConfirmation?.previousLevels ?? [:]
        for key in changed { revertTo[key] = asking.contains(key) ? .standard : nil }
        guard !revertTo.isEmpty else {
            if let pending = pendingConfirmation {
                pendingConfirmation = nil
                confirmationSlot.cancel()
                journal.record("keep.ended", display: pending.display, time: time)
            }
            return
        }
        guard !asking.isEmpty else {
            // Nothing new to ask: the pending question keeps its display and deadline, without the settled displays.
            pendingConfirmation?.previousLevels = revertTo
            return
        }
        let shown = display ?? (revertTo.count == 1 ? revertTo.keys.first : pendingConfirmation?.display)
        pendingConfirmation = LevelConfirmation(display: shown, previousLevels: revertTo, deadline: confirmationDeadline)
        journal.record("keep.asked", display: shown, time: time)
        armConfirmationRevert()
    }

    /// Turning Overbright on with a level away from Standard asks too (the same rule, the master as the change), except
    /// for levels inside the range kept on their display.
    func askToKeepAfterTurningOn(source: ControlSource) {
        guard keepPromptEnabled, Self.turnOnPromptSources.contains(source), isMasterOn else { return }
        let keys = displays.displays.map(\.ref.key).filter { !isKept(storedLevel(of: $0), on: $0) }
        guard !keys.isEmpty else { return }
        let revertTo = Self.byKey(keys.map { ($0, LevelPosition.standard) })
        let shown = keys.count == 1 ? keys.first : nil
        pendingConfirmation = LevelConfirmation(display: shown, previousLevels: revertTo, deadline: confirmationDeadline)
        journal.record("keep.asked", display: shown, time: time)
        armConfirmationRevert()
    }

    /// Writes the levels of the pending confirmation back and forgets it.
    func restorePreviousLevels() {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        confirmationSlot.cancel()
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

    /// The range kept on `key` that still holds: kept on this macOS build with the display's winning rung now. A
    /// different build or rung clears it (nil).
    func keptRange(of key: DisplayKey) -> KeptLevelRange? {
        guard let range = settings[DisplaySettings.perDisplay][key]?.keptRange,
              range.holds(osBuild: machine.osBuild, rung: winningRung(of: key)) else { return nil }
        return range
    }

    /// Whether `level` on `key` needs no question: Standard, or inside the range kept there.
    func isKept(_ level: LevelPosition, on key: DisplayKey) -> Bool {
        level == .standard || keptRange(of: key)?.contains(level) == true
    }

    // MARK: Internals

    /// When a question asked now goes back by itself.
    private var confirmationDeadline: Date { time.wallClock + EngineTiming.levelConfirmTimeout.timeInterval }

    /// The display's winning trigger rung on this build (`StrategyCache`); nil before one is learned.
    private func winningRung(of key: DisplayKey) -> Int? {
        strategyCache.record(for: key, osBuild: machine.osBuild)?.rung
    }

    /// Keep widens the kept range of each display by its level now; a range that no longer holds starts again.
    private func widenKeptRanges(_ keys: some Sequence<DisplayKey>) {
        var all = settings[DisplaySettings.perDisplay]
        var changed = false
        for key in keys {
            let level = storedLevel(of: key)
            guard level != .standard else { continue }
            let base = keptRange(of: key) ?? KeptLevelRange(osBuild: machine.osBuild, rung: winningRung(of: key))
            var preferences = all[key] ?? DisplayPreferences()
            preferences.keptRange = base.widened(by: level)
            all[key] = preferences
            changed = true
        }
        if changed { settings[DisplaySettings.perDisplay] = all }
    }

    /// The 10 s revert of the pending confirmation (§4.9).
    private func armConfirmationRevert() {
        confirmationSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.levelConfirmTimeout) } catch { return }
            guard let pending = self.pendingConfirmation else { return }
            self.journal.record("keep.reverted", display: pending.display, time: self.time)
            self.restorePreviousLevels()
            self.reduceNow()
        }
    }
}
