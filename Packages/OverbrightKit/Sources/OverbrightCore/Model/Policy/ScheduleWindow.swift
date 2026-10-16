// OverbrightCore/Model/Policy/ScheduleWindow.swift — "only during set hours". ARCHITECTURE.md §3.4, D10.

/// "Only allow extra brightness during set hours". Minutes since local midnight; `end < start` spans midnight, and
/// `end == start` is the whole day (the Settings pickers pass through equal ends while either is stepped).
public nonisolated struct ScheduleWindow: Hashable, Codable, Sendable {
    /// First allowed minute of the day (0…1439).
    public var startMinute: Int
    /// First minute no longer allowed (0…1439).
    public var endMinute: Int
    /// A window; both minutes are clamped to 0…1439.
    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(max(startMinute, 0), 1439); self.endMinute = min(max(endMinute, 0), 1439)
    }
    /// Whether the local minute `m` lies inside the window (start inclusive, end exclusive; always, when they are
    /// equal: a window from 08:00 to 08:00 is 24 hours, never none).
    public func contains(minuteOfDay m: Int) -> Bool {
        if startMinute == endMinute { return true }
        return startMinute < endMinute ? (m >= startMinute && m < endMinute) : (m >= startMinute || m < endMinute)
    }
}
