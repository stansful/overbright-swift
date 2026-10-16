// OverbrightCore/Fakes/PreviewUpdateChecking.swift — an in-memory UpdateChecking. ARCHITECTURE.md §3.9, D2.
import Foundation
import Observation

/// An `UpdateChecking` with settable state and no network.
@MainActor @Observable public final class PreviewUpdateChecking: UpdateChecking {
    /// False by default, like a build with an empty repository key.
    public var isConfigured: Bool
    /// The last result (settable).
    public var state: UpdateState
    /// Number of `checkNow()` calls.
    public private(set) var checkCount = 0
    /// Not configured, idle by default.
    public init(isConfigured: Bool = false, state: UpdateState = .idle) {
        self.isConfigured = isConfigured; self.state = state
    }
    /// Counts the call; when configured, reports "up to date" as of a fixed date.
    public func checkNow() {
        checkCount += 1
        guard isConfigured else { return }
        state = .upToDate(checkedAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
    }
}
