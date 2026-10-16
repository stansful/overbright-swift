// OverbrightCore/Model/Displays/MonotonicInstant.swift — a point on a TimeSource's monotonic clock. ARCHITECTURE.md §3.2.
import Foundation

/// A point on the monotonic clock of a `TimeSource` (never wall-clock time).
public nonisolated struct MonotonicInstant: Hashable, Comparable, Sendable, Codable {
    /// Time since the time source's origin.
    public var sinceOrigin: Duration
    /// The instant `sinceOrigin` after the time source's origin.
    public init(sinceOrigin: Duration) { self.sinceOrigin = sinceOrigin }
    /// Earlier instants sort first.
    public static func < (a: Self, b: Self) -> Bool { a.sinceOrigin < b.sinceOrigin }
    /// The instant `d` after `a`.
    public static func + (a: Self, d: Duration) -> Self { Self(sinceOrigin: a.sinceOrigin + d) }
    /// The time from `b` to `a` (negative when `a` is earlier).
    public static func - (a: Self, b: Self) -> Duration { a.sinceOrigin - b.sinceOrigin }
}
