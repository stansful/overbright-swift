// OverbrightAppShell/App/DiagnosticsReport+Shell.swift — the diagnostics inputs of a shell: `--diagnostics` (bundle
// facts, the strategy cache read from its file, no service started) and Advanced ▸ Copy Diagnostics (the journal, the
// engine's own cache). ARCHITECTURE.md §8.4, D24. Read-only: the cache file is decoded as it is, never moved aside
// or rewritten (`JSONDocumentFile.load()` would set a corrupt file aside).
import Foundation
import OverbrightBoost
import OverbrightCore

extension DiagnosticsReport.Inputs {
    /// The inputs of `shell`.
    static func of(_ shell: Shell, forClipboard: Bool) -> DiagnosticsReport.Inputs {
        let ports = shell.ports
        let services = shell.services
        var inputs = DiagnosticsReport.Inputs(
            settings: services.settings, machine: services.machine, journal: services.journal,
            iconVisibility: services.app?.iconVisibility ?? .visible, gamma: ports.gamma, headroom: ports.headroom,
            triggers: ports.triggers, displays: ports.readDisplays(), signals: ports.signals,
            conflicts: ports.conflicts, profileHasVCGT: ports.profileHasVCGT, simulatedFixture: ports.fixture?.rawValue,
            includesBundleFacts: !forClipboard, includesJournal: forClipboard)
        inputs.strategyRecords = strategyRecords(shell)
        inputs.backlightMilliNits = ports.backlightMilliNits()
        inputs.services = shell.lifecycle.map(\.serviceName)
        return inputs
    }

    /// The engine's records once it has started; before that (`--diagnostics`), the cache file's, read-only.
    private static func strategyRecords(_ shell: Shell) -> [String: StrategyRecord] {
        if let engine = shell.engine, engine.status.isReady { return engine.strategyCache.records }
        let url = shell.services.paths.caches.appending(path: CompositionRoot.strategyCacheFileName)
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: StrategyRecord].self, from: data)) ?? [:]
    }
}
