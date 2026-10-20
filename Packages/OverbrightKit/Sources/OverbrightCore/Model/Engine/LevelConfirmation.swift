// OverbrightCore/Model/Engine/LevelConfirmation.swift — the pending "Keep this level?". ARCHITECTURE.md §3.5, §4.9, §5.9.
import Foundation

/// "Keep this level?" after a person moved a display's level away from Standard, or turned Overbright on with a level
/// away from Standard (§4.9). Goes back at `deadline`.
public nonisolated struct LevelConfirmation: Hashable, Sendable {
    /// The display whose control moved (the prompt shows on it); nil = every display.
    public var display: DisplayKey?
    /// The levels restored if nobody confirms: Standard for every display the question covers.
    public var previousLevels: [DisplayKey: LevelPosition]
    /// When the engine reverts by itself.
    public var deadline: Date
    /// A pending confirmation.
    public init(display: DisplayKey?, previousLevels: [DisplayKey: LevelPosition], deadline: Date) {
        self.display = display; self.previousLevels = previousLevels; self.deadline = deadline
    }
}
