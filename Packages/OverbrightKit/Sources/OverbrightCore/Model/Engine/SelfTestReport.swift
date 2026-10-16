// OverbrightCore/Model/Engine/SelfTestReport.swift — the saved self-test log. ARCHITECTURE.md §3.5, §8.2, §8.4.
import Foundation

/// The self-test log the user can save or copy (JSON).
public nonisolated struct SelfTestReport: Hashable, Codable, Sendable {
    /// When the run started.
    public var startedAt: Date
    /// Model and OS build.
    public var machine: MachineIdentity
    /// The app version.
    public var appVersion: String
    /// `DisplayKey.rawValue` → results.
    public var displays: [String: [SelfTestStrategyResult]]
    /// The journal during the run.
    public var journal: [JournalEvent]
    /// A report.
    public init(startedAt: Date, machine: MachineIdentity, appVersion: String,
                displays: [String: [SelfTestStrategyResult]], journal: [JournalEvent]) {
        self.startedAt = startedAt; self.machine = machine; self.appVersion = appVersion
        self.displays = displays; self.journal = journal
    }
}
