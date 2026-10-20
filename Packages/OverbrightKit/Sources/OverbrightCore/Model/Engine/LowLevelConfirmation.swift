// OverbrightCore/Model/Engine/LowLevelConfirmation.swift — the pending "Keep this level?". ARCHITECTURE.md §3.5, §4.9, §5.9.
import Foundation

/// "Keep this level?" after a level below 10 % of Standard light was set (§5.9), or after a display's first boost on
/// this macOS build (§4.9). Reverts at `deadline`.
public nonisolated struct LowLevelConfirmation: Hashable, Sendable {
    /// The display that went low or was boosted; nil = every display.
    public var display: DisplayKey?
    /// The levels restored if nobody confirms.
    public var previousLevels: [DisplayKey: LevelPosition]
    /// When the engine reverts by itself.
    public var deadline: Date
    /// The displays whose first boost on this macOS build this confirmation asks about; Keep records the build for
    /// them (`DisplayPreferences.boostConfirmedBuild`). Empty for a very dark level.
    public var firstBoostDisplays: [DisplayKey]
    /// A pending confirmation.
    public init(display: DisplayKey?, previousLevels: [DisplayKey: LevelPosition], deadline: Date,
                firstBoostDisplays: [DisplayKey] = []) {
        self.display = display; self.previousLevels = previousLevels; self.deadline = deadline
        self.firstBoostDisplays = firstBoostDisplays
    }
}
