// OverbrightBoost/Ladder/LadderRung.swift — one rung of the trigger ladder. ARCHITECTURE.md §4.7 (the rung table), D4.
import OverbrightCore

/// One rung of the escalation ladder: its number in the table of §4.7 (stable, persisted by `StrategyCache`), the
/// strategy and the pixel it shows.
public nonisolated struct LadderRung: Hashable, Sendable, CustomStringConvertible {
    /// The rung's number in §4.7 (1 = T1 black … 7 = T4 at peak). Persisted; never renumber.
    public var number: Int
    /// The trigger strategy.
    public var strategy: TriggerStrategy
    /// The pixel it shows.
    public var pixel: TriggerPixel
    /// The oldest macOS major version it runs on.
    public var minimumOS: Int

    /// A rung.
    public init(number: Int, strategy: TriggerStrategy, pixel: TriggerPixel, minimumOS: Int = 14) {
        self.number = number; self.strategy = strategy; self.pixel = pixel; self.minimumOS = minimumOS
    }

    /// "3:metalOneShot/black", for logs and failure messages.
    public var description: String { "\(number):\(strategy.rawValue)/\(pixel.rawValue)" }
}
