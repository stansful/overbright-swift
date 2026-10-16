// OverbrightCore/Fakes/FakeConflictProbe.swift — a ConflictProbe with a settable running list. ARCHITECTURE.md §3.9, §7.2.

/// A `ConflictProbe` whose running conflicts and drift attribution tests set.
@MainActor public final class FakeConflictProbe: ConflictProbe {
    /// What `runningConflicts()` returns.
    public var running: [ConflictingApp]
    /// What `attributeDrift()` names (nil: nobody).
    public var driftAttribution: ConflictingApp?
    /// Number of `attributeDrift()` calls.
    public private(set) var attributionRequests = 0

    /// A probe with nothing running by default.
    public init(running: [ConflictingApp] = [], driftAttribution: ConflictingApp? = nil) {
        self.running = running; self.driftAttribution = driftAttribution
    }

    /// `running`.
    public func runningConflicts() -> [ConflictingApp] { running }
    /// Counts the request and returns `driftAttribution`.
    public func attributeDrift() async -> ConflictingApp? {
        attributionRequests += 1
        return driftAttribution
    }
}
