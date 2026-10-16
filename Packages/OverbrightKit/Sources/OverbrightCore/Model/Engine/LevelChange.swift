// OverbrightCore/Model/Engine/LevelChange.swift — the last change the HUD may show. ARCHITECTURE.md §3.5, §4.9; DESIGN.md §6.

/// The last change the HUD may show (DESIGN.md §6). The shell shows it when `sequence` increases.
public nonisolated struct LevelChange: Hashable, Sendable {
    /// What changed.
    public enum Kind: Hashable, Sendable {
        /// A level or on/off change by `source`.
        case level
        /// The requested boost waits for extra range (> 0.5 s).
        case preparing
        /// A requested change was stopped by a guard.
        case blocked(LimitReason)
        /// A guard stopped or capped the boost on its own.
        case automationStopped(LimitReason)
        /// The boost came back after a guard cleared.
        case automationResumed
        /// The auto-off timer ended.
        case timerEnded
    }
    /// Increases with every change.
    public var sequence: UInt64
    /// What changed.
    public var kind: Kind
    /// Who asked.
    public var source: ControlSource
    /// nil = every display.
    public var display: DisplayKey?
    /// A change.
    public init(sequence: UInt64, kind: Kind, source: ControlSource, display: DisplayKey?) {
        self.sequence = sequence; self.kind = kind; self.source = source; self.display = display
    }
}
