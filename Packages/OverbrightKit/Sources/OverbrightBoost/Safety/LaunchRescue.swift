// OverbrightBoost/Safety/LaunchRescue.swift — the launch check and the dirty-then-restore rescue. ARCHITECTURE.md
// §7.4, D7, D26, D27. Thread: main. Owned by WP5 (seeded by WP0a with the §10.0 initializer).
//
// The launch check, before any other display work: not on the console → skip (and run again when the session comes
// back); read every online table and judge it against its profile base (never by its maximum); neutral → done (a
// boost marker then means "we died and WindowServer restored"); scaled or invalid while a catalogued table writer
// (S1–S3) runs → theirs, touch nothing; otherwise dirty-then-restore: write one read-back table unchanged (so our
// connection counts as a table writer), call the global restore, re-read every display and verify it, write the
// profile base explicitly where the restore left something implausible (e.g. all zeros), and report what still
// classifies scaled as a session-level residue. The global restore is never called alone: from a process that wrote no
// table it does nothing. `rescueNow()` (`--restore-gamma`, Reset Display Colors) runs the same restore on every display
// whatever the classification, the marker or other apps say; it never writes a preference.
import Foundation
import OverbrightCore
import OverbrightPolicy
import os

private let log = Log.logger(.gamma)

/// Decides at launch (and for `--restore-gamma` and Advanced ▸ Reset Display Colors) whether a display carries a
/// leftover table, and clears it. With `TableWriter`, the only caller of `GammaPort.write` and
/// `restoreSystemColorSettings()` (lint test `onlyTableWriterAndRescueWrite`).
public final class LaunchRescue {
    /// Judges a read table against its expected base (Policy's `TableClassifier.classify`, D26).
    typealias Classify = (_ read: GammaTable, _ expectedBase: GammaTable) -> TableClass
    /// The post-restore check (Policy's `TableClassifier.isPlausibleRestore`).
    typealias PlausibleRestore = (_ read: GammaTable, _ expectedBase: GammaTable) -> Bool

    /// One online display with a transfer table, as read before the restore.
    struct Survey: Hashable {
        /// The display.
        var display: DisplayRef
        /// Its live table (read-back).
        var table: GammaTable
        /// Its profile base at the table's length.
        var base: GammaTable
        /// `table` judged against `base`.
        var tableClass: TableClass
        /// Scaled (up or down) or invalid: what the launch check rescues.
        var needsRescue: Bool {
            switch tableClass {
            case .scaled, .invalid: true
            case .matchesBase, .foreign: false
            }
        }
    }

    private let gamma: any GammaPort
    private let conflicts: any ConflictProbe
    private let signals: any SystemSignals
    private let journal: any DiagnosticsJournal
    private let time: any TimeSource
    private let onlineDisplays: @MainActor () -> [DisplayRef]
    private let settings: SettingsStore?
    private let classify: Classify
    private let isPlausibleRestore: PlausibleRestore
    private var consoleWait: ObservationToken?

    /// The launch check that waits for the session to return to the console (D27), once one was skipped.
    public private(set) var deferredCheck: Task<RescueOutcome, Never>?
    /// The outcome of the last launch check or rescue.
    public private(set) var lastOutcome: RescueOutcome?
    /// Called with the outcome of a launch check that ran later, when the session returned to the console.
    public var onDeferredOutcome: ((RescueOutcome) -> Void)?

    /// A rescue over the real or fake ports that reads the online displays from CoreGraphics (read-only) and keeps no
    /// boost marker. Prefer `init(gamma:conflicts:signals:journal:time:displays:settings:)`.
    public convenience init(gamma: any GammaPort, conflicts: any ConflictProbe, signals: any SystemSignals,
                            journal: any DiagnosticsJournal) {
        self.init(gamma: gamma, conflicts: conflicts, signals: signals, journal: journal, time: SystemTimeSource(),
                  displays: OnlineDisplays.coreGraphics, settings: nil)
    }

    /// A rescue over the real or fake ports. `displays` lists the online displays (the composition root passes its
    /// read-only snapshot; the services have not started when the launch check runs); `settings` holds the boost
    /// marker (`EngineRecords.boostMarker`), which the launch check reads and clears; `time` stamps the journal.
    public convenience init(gamma: any GammaPort, conflicts: any ConflictProbe, signals: any SystemSignals,
                            journal: any DiagnosticsJournal, time: any TimeSource,
                            displays: @escaping @MainActor () -> [DisplayRef], settings: SettingsStore?) {
        self.init(gamma: gamma, conflicts: conflicts, signals: signals, journal: journal, time: time,
                  displays: displays, settings: settings, classify: TableClassifier.classify(_:expectedBase:),
                  isPlausibleRestore: TableClassifier.isPlausibleRestore(_:expectedBase:))
    }

    /// The designated initializer; tests inject the classifier.
    init(gamma: any GammaPort, conflicts: any ConflictProbe, signals: any SystemSignals,
         journal: any DiagnosticsJournal, time: any TimeSource, displays: @escaping @MainActor () -> [DisplayRef],
         settings: SettingsStore?, classify: @escaping Classify, isPlausibleRestore: @escaping PlausibleRestore) {
        self.gamma = gamma; self.conflicts = conflicts; self.signals = signals; self.journal = journal
        self.time = time; self.onlineDisplays = displays; self.settings = settings
        self.classify = classify; self.isPlausibleRestore = isPlausibleRestore
    }

    // MARK: Entry points

    /// The launch check (§7.4), before any other display work. Skipped while the session is not on the console; it then
    /// runs by itself when the session becomes active (`deferredCheck`, `onDeferredOutcome`).
    public func runLaunchCheck() async -> RescueOutcome {
        launchCheck(onConsole: signals.snapshot.isSessionActive)
    }

    /// Dirty-then-restore with verification on every display, whatever the boost marker, the classification or other
    /// apps say (`--restore-gamma`, Reset Display Colors). Writes no preference. Skipped off the console (D27).
    public func rescueNow() async -> RescueOutcome {
        guard signals.snapshot.isSessionActive else {
            record("rescue.notOnConsole")
            return finish(.skippedNotOnConsole)
        }
        let before = survey()
        guard !before.isEmpty else { return finish(.alreadyNeutral) }
        let order = before.filter(\.needsRescue) + before.filter { !$0.needsRescue }
        let outcome = dirtyThenRestore(before, dirtyFirst: order)
        record("rescue.manual", values: summary(of: outcome))
        log.info("rescue: \(String(describing: outcome), privacy: .public)")
        return finish(outcome)
    }

    // MARK: Launch check

    /// The launch check proper. `onConsole` comes from the snapshot, or is true when `sessionBecameActive` arrived.
    func launchCheck(onConsole: Bool) -> RescueOutcome {
        guard onConsole else {
            record("launch.notOnConsole")
            log.info("launch check skipped: the session is not on the console")
            waitForConsole()
            return finish(.skippedNotOnConsole)
        }
        stopWaitingForConsole()
        let hadMarker = settings?[EngineRecords.boostMarker] != nil
        let before = survey()
        let affected = before.filter(\.needsRescue)
        for foreign in before where foreign.tableClass == .foreign {
            record("launch.foreignTable", display: foreign.display.key)
        }
        guard !affected.isEmpty else {
            if hadMarker { record("launch.recoveredByWindowServer", values: ["displays": Double(before.count)]) }
            clearMarker()
            return finish(.alreadyNeutral)
        }
        if let writer = knownTableWriter() {
            record("launch.skippedTableWriter", values: ["displays": Double(affected.count),
                                                         "processID": Double(writer.processID)])
            log.info("launch check: a known table writer runs; \(affected.count, privacy: .public) table(s) left alone")
            clearMarker()
            return finish(.skippedBecauseTableWriterRuns(writer))
        }
        let outcome = dirtyThenRestore(before, dirtyFirst: affected)
        record("launch.rescued", values: summary(of: outcome).merging(["marker": hadMarker ? 1 : 0]) { $1 })
        log.info("launch rescue: \(String(describing: outcome), privacy: .public)")
        clearMarker()
        return finish(outcome)
    }

    /// A running S1–S3 app (S1 first): a non-base table is theirs (§7.2).
    private func knownTableWriter() -> ConflictingApp? {
        let order: [ConflictSeverity] = [.booster, .gammaWriter, .conditional]
        return conflicts.runningConflicts()
            .filter { order.contains($0.severity) }
            .min { (order.firstIndex(of: $0.severity) ?? 0) < (order.firstIndex(of: $1.severity) ?? 0) }
    }

    // MARK: Dirty-then-restore

    /// Every online display with a transfer table, read and classified (read-only).
    func survey() -> [Survey] {
        onlineDisplays().compactMap { display -> Survey? in
            guard gamma.capacity(of: display.id) > 0 else { return nil }
            do {
                let table = try gamma.read(display.id)
                let base = gamma.profileBase(of: display.id, count: table.count)
                return Survey(display: display, table: table, base: base, tableClass: classify(table, base))
            } catch {
                record("rescue.readFailed", display: display.key)
                return nil
            }
        }
    }

    /// Writes the first writable table of `candidates` back unchanged, calls the global restore, then verifies every
    /// display of `before`, writing the profile base where the restore left an implausible table.
    func dirtyThenRestore(_ before: [Survey], dirtyFirst candidates: [Survey]) -> RescueOutcome {
        for candidate in candidates {
            do {
                try gamma.write(candidate.table, to: candidate.display.id)
                break
            } catch {
                record("rescue.dirtyWriteFailed", display: candidate.display.key)
            }
        }
        gamma.restoreSystemColorSettings()

        var repaired: [DisplayKey] = []
        var residue: [DisplayKey] = []
        var changed = 0
        for entry in before {
            let id = entry.display.id, key = entry.display.key
            guard var after = try? gamma.read(id) else { continue }          // gone since the survey
            let base = gamma.profileBase(of: id, count: after.count)
            if !isPlausibleRestore(after, base) {
                do {
                    try gamma.write(base, to: id)
                    repaired.append(key)
                    record("launch.repairedInvalidRestore", display: key)
                    after = (try? gamma.read(id)) ?? base
                } catch {
                    record("rescue.repairFailed", display: key)
                }
            }
            switch classify(after, base) {
            case .scaled, .invalid:
                residue.append(key)
                record("launch.residueRemains", display: key)
            case .matchesBase, .foreign:
                break
            }
            if after != entry.table { changed += 1 }
        }
        if !residue.isEmpty { return .residueRemains(displays: residue) }
        if !repaired.isEmpty { return .repairedInvalidRestore(displays: repaired) }
        return changed == 0 ? .alreadyNeutral : .restored(displays: changed)
    }

    // MARK: Console (D27)

    private func waitForConsole() {
        guard consoleWait == nil else { return }
        consoleWait = signals.addEventObserver { [weak self] event in
            guard case .sessionBecameActive = event, let self else { return }
            self.stopWaitingForConsole()
            self.deferredCheck = Task { @MainActor [weak self] in
                guard let self else { return .skippedNotOnConsole }
                let outcome = self.launchCheck(onConsole: true)
                self.onDeferredOutcome?(outcome)
                return outcome
            }
        }
    }

    private func stopWaitingForConsole() {
        consoleWait?.cancel()
        consoleWait = nil
    }

    // MARK: Helpers

    private func finish(_ outcome: RescueOutcome) -> RescueOutcome {
        lastOutcome = outcome
        return outcome
    }

    private func clearMarker() {
        guard let settings, settings[EngineRecords.boostMarker] != nil else { return }
        settings[EngineRecords.boostMarker] = nil
    }

    private func summary(of outcome: RescueOutcome) -> [String: Double] {
        switch outcome {
        case .alreadyNeutral: ["restored": 0]
        case .restored(let displays): ["restored": Double(displays)]
        case .repairedInvalidRestore(let displays): ["repaired": Double(displays.count)]
        case .residueRemains(let displays): ["residue": Double(displays.count)]
        case .skippedBecauseTableWriterRuns, .skippedNotOnConsole: [:]
        }
    }

    private func record(_ code: String, display: DisplayKey? = nil, values: [String: Double] = [:]) {
        journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: LogCategory.gamma.rawValue,
                                    display: display?.rawValue, code: code, values: values))
    }
}
