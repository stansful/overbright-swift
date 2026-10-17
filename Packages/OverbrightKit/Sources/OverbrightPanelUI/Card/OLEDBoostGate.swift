// OverbrightPanelUI/Card/OLEDBoostGate.swift — a slider move into the boost half of an OLED display whose extra
// brightness is off and whose notice was never answered: the thumb waits at Standard while the move goes on, and the
// notice is asked once, when it ends, for the level it ended at. DESIGN.md §5.4 ("the thumb waits at Standard until the
// notice is answered"), §12.4. Moving back to Standard or below drops the waiting level, so releasing there asks
// nothing and a later Turn On never sets a level the thumb already left.
import OverbrightCore

/// The boost level of a move that waits for the OLED notice.
struct OLEDBoostGate: Hashable {
    /// The latest boost level of the current move that waits for the notice; nil when none waits.
    private(set) var pending: LevelPosition?

    /// The level to show and set for a move to `level`: Standard while it is a boost level that waits for the notice
    /// (`waitsForNotice`), else `level` itself, which also drops a waiting level.
    mutating func move(to level: LevelPosition, waitsForNotice: Bool) -> LevelPosition {
        guard level.isBoost, waitsForNotice else {
            pending = nil
            return level
        }
        pending = level
        return .standard
    }

    /// The end of the move: the boost level to ask the notice for, nil when the move ended at Standard or below.
    mutating func release() -> LevelPosition? {
        defer { pending = nil }
        return pending
    }
}
