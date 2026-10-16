// OverbrightBoost/Ladder/StrategyCache.swift — the learned rung and the lowest ready headroom per display UUID and
// `kern.osversion`. ARCHITECTURE.md §4.7, §5.4, §8.2 (`~/Library/Caches/app.overbright.Overbright/strategy-cache.json`).
// MainActor. In memory unless the composition root gives it a file (`BoostEngine.useStrategyCache(at:)`); the file is
// read once at start and written in the background after each change (a cache: safe to delete, never authoritative).
import Foundation
import OverbrightCore

/// Per display and OS build: the winning rung (replaced by a heavier one only after it failed in two separate normal
/// arms outside the wake/unlock quarantine) and the lowest headroom at which a gate became ready.
@MainActor public final class StrategyCache {
    /// Failures of the cached rung, in separate arms, before a heavier winner replaces it (§4.7).
    public static let replacementFailures = 2

    /// Every record by "<display UUID>|<OS build>".
    public private(set) var records: [String: StrategyRecord] = [:]
    private var file: JSONDocumentFile<[String: StrategyRecord]>?
    private var revision = 0
    private var saving: Task<Void, Never>?

    /// An empty cache, in memory until `attach(file:)`.
    public init() {}

    /// The key of `display` on `osBuild`.
    public nonisolated static func key(_ display: DisplayKey, osBuild: String) -> String { "\(display.rawValue)|\(osBuild)" }

    /// The record of `display` on `osBuild`.
    public func record(for display: DisplayKey, osBuild: String) -> StrategyRecord? {
        records[Self.key(display, osBuild: osBuild)]
    }

    /// Keeps the cache in `file` from now on, after reading what is there (a missing or corrupt file is an empty cache).
    public func attach(file: JSONDocumentFile<[String: StrategyRecord]>) async {
        self.file = file
        if case .loaded(let stored)? = try? await file.loadInBackground() {
            records.merge(stored) { current, _ in current }
        }
    }

    // MARK: Learning

    /// A normal arm became ready on `rung`. The first winner is cached; the cached rung winning again clears its
    /// failures; a heavier winner replaces it only after `replacementFailures` failed arms. Pre-held arms never call
    /// this (§4.7).
    public func recordWin(rung: Int, for display: DisplayKey, osBuild: String) {
        update(display, osBuild) { record in
            guard let cached = record.rung else {
                record.rung = rung; record.failures = 0
                return
            }
            if rung == cached {
                record.failures = 0
            } else if rung > cached, record.failures >= Self.replacementFailures {
                record.rung = rung; record.failures = 0
            }
        }
    }

    /// The cached rung failed in a normal arm (once per arm). Failures within the wake/unlock quarantine are not
    /// counted (`quarantined`), so a slow grant after wake never caches a heavier rung for the whole build.
    public func recordFailure(rung: Int, for display: DisplayKey, osBuild: String, quarantined: Bool) {
        guard !quarantined, record(for: display, osBuild: osBuild)?.rung == rung else { return }
        update(display, osBuild) { $0.failures += 1 }
    }

    /// A gate became ready at headroom `headroom`: keeps the lowest one (§5.4's `H_full`).
    public func learnReadyHeadroom(_ headroom: Double, for display: DisplayKey, osBuild: String) {
        guard headroom.isFinite, headroom > 1 else { return }
        update(display, osBuild) { record in
            record.lowestReadyHeadroom = min(record.lowestReadyHeadroom ?? headroom, headroom)
        }
    }

    /// Advanced ▸ "Forget learned methods": every record goes.
    public func forget() {
        records = [:]
        save()
    }

    // MARK: Persistence

    private func update(_ display: DisplayKey, _ osBuild: String, _ change: (inout StrategyRecord) -> Void) {
        let key = Self.key(display, osBuild: osBuild)
        var record = records[key] ?? StrategyRecord()
        change(&record)
        guard records[key] != record else { return }
        records[key] = record
        save()
    }

    private func save() {
        guard let file else { return }
        revision += 1
        let snapshot = records, revision = revision
        saving = Task(priority: .utility) {
            _ = try? await file.writeInBackground(snapshot, revision: revision)
        }
    }
}
