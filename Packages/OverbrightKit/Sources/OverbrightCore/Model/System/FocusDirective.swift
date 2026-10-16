// OverbrightCore/Model/System/FocusDirective.swift — what the active Focus filter asks for. ARCHITECTURE.md §3.3, D18.

/// What the active Focus filter asks for (D18). `leaveAlone` is the default and the "no filter" state.
public nonisolated enum FocusDirective: Hashable, Codable, Sendable {
    /// No filter, or a filter that leaves Overbright alone.
    case leaveAlone
    /// Extra brightness off while the Focus is active.
    case off
    /// On at `level` for every display.
    case on(level: LevelPosition)
}
