// OverbrightCore/Model/Displays/KeptLevelRange.swift — the levels a person already kept on a display.
// ARCHITECTURE.md §3.2, §4.9; DESIGN.md §6.

/// The range of levels a person kept with "Keep this level?" on one display (§4.9): from the lowest kept dim to the
/// highest kept boost, Standard always inside. Valid only on the macOS build (`MachineIdentity.osBuild`) and with the
/// winning trigger rung (`StrategyCache`) it was kept with, since either can change how a scaled table looks.
public nonisolated struct KeptLevelRange: Hashable, Codable, Sendable {
    /// The highest boost level kept; nil = no boost kept.
    public var highestBoost: LevelPosition?
    /// The lowest dim level kept; nil = no dim kept.
    public var lowestDim: LevelPosition?
    /// The macOS build at Keep time.
    public var osBuild: String
    /// The display's winning trigger rung at Keep time; nil = none learned yet.
    public var rung: Int?
    /// A kept range.
    public init(highestBoost: LevelPosition? = nil, lowestDim: LevelPosition? = nil, osBuild: String, rung: Int?) {
        self.highestBoost = highestBoost; self.lowestDim = lowestDim; self.osBuild = osBuild; self.rung = rung
    }

    /// Whether `level` lies within the kept range (Standard always does).
    public func contains(_ level: LevelPosition) -> Bool {
        level <= (highestBoost ?? .standard) && level >= (lowestDim ?? .standard)
    }

    /// Whether the range still holds on `osBuild` with `rung`.
    public func holds(osBuild: String, rung: Int?) -> Bool { self.osBuild == osBuild && self.rung == rung }

    /// The range widened to take `level` in.
    public func widened(by level: LevelPosition) -> KeptLevelRange {
        var range = self
        if level.isBoost { range.highestBoost = max(highestBoost ?? level, level) }
        if level.isDim { range.lowestDim = min(lowestDim ?? level, level) }
        return range
    }
}
