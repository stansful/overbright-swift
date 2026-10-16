// OverbrightCore/Model/Engine/JournalEvent.swift — one line of the diagnostics journal. ARCHITECTURE.md §3.5, §8.3.

/// One line of the diagnostics journal. Codes and numbers only; no user content (names are added by the UI).
public nonisolated struct JournalEvent: Hashable, Codable, Sendable {
    /// Monotonic seconds since launch.
    public var seconds: Double
    /// A `LogCategory` raw value.
    public var category: String
    /// `DisplayKey.rawValue`.
    public var display: String?
    /// Stable machine code, e.g. "gate.ready", "watchdog.drift".
    public var code: String
    /// Numbers that go with the code.
    public var values: [String: Double]
    /// An event.
    public init(seconds: Double, category: String, display: String?, code: String, values: [String: Double] = [:]) {
        self.seconds = seconds; self.category = category; self.display = display; self.code = code; self.values = values
    }
}
