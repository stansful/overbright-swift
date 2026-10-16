// OverbrightCore/Model/Engine/LowLevelConfirmation.swift — the pending "Keep this level?". ARCHITECTURE.md §3.5, §4.9, §5.9.
import Foundation

/// "Keep this level?" after a level below 10 % of Standard light was set (§5.9). Reverts at `deadline`.
public nonisolated struct LowLevelConfirmation: Hashable, Sendable {
    /// The display that went low; nil = every display.
    public var display: DisplayKey?
    /// The levels restored if nobody confirms.
    public var previousLevels: [DisplayKey: LevelPosition]
    /// When the engine reverts by itself.
    public var deadline: Date
    /// A pending confirmation.
    public init(display: DisplayKey?, previousLevels: [DisplayKey: LevelPosition], deadline: Date) {
        self.display = display; self.previousLevels = previousLevels; self.deadline = deadline
    }
}
