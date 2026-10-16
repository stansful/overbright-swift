// OverbrightBoost/Writer/DiagnosticsJournal+Engine.swift — how the engine and the writer journal a stable code.
// ARCHITECTURE.md §8.3 (codes and numbers only; never names or paths). Nonisolated: the writer journals from the hang
// watchdog's and the signal queue's threads too.
import OverbrightCore

extension DiagnosticsJournal {
    /// Records `code` for `display` (nil: the whole engine) at `time.now`, in `category` (a `LogCategory`).
    nonisolated func record(_ code: String, display: DisplayKey?, values: [String: Double] = [:],
                            time: any TimeSource, category: LogCategory = .engine) {
        record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: category.rawValue,
                            display: display?.rawValue, code: code, values: values))
    }
}
