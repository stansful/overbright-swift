// OverbrightBoost/Safety/SignalHandlers.swift — TERM, INT and HUP restore the displays before the process exits.
// ARCHITECTURE.md §7.4, §8.1 rule 2; D7. Thread: a dedicated serial queue (`DispatchSource.makeSignalSource`), never
// the main actor. Seeded by WP0a with the fixed signatures (§10.0); owned by WP5 (body, `SignalStopTests`). The WP0a
// body installs nothing, so the signals keep their default behaviour.
import OverbrightCore

/// On a signal: ledger baselines through `writer` at once, then the main-actor `stop` with a 1 s timeout, then exit.
public nonisolated final class SignalHandlers: Sendable {
    private let writer: TableWriter
    private let stop: @MainActor @Sendable () async -> Void

    /// Handlers that write through `writer` and then ask for `stop` (the engine's ramped stop).
    public init(writer: TableWriter, stop: @escaping @MainActor @Sendable () async -> Void) {
        self.writer = writer; self.stop = stop
    }

    /// Ignores the default actions of TERM, INT and HUP and installs the dispatch sources. WP0a seed: does nothing.
    public func install() {}
}
