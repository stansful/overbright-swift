// OverbrightCore/Model/Engine/BoostStatus.swift — everything the engine publishes. ARCHITECTURE.md §3.5, §4.1.
import Foundation

/// Everything `BoostControl.status` publishes.
public nonisolated struct BoostStatus: Hashable, Sendable {
    /// The master switch.
    public var isOn: Bool
    /// The engine finished its launch work (launch check, first reduction); intents wait for this (≤ 5 s).
    public var isReady: Bool
    /// "Pause for…" deadline.
    public var pausedUntil: Date?
    /// Auto-off deadline.
    public var autoOffAt: Date?
    /// One status per online display.
    public var displays: [DisplayStatus]
    /// The panel's banner.
    public var banner: Banner?
    /// The menu bar symbol.
    public var symbol: StatusSymbolState
    /// The last change the HUD may show.
    public var lastChange: LevelChange?
    /// A pending "Keep this level?".
    public var pendingConfirmation: LevelConfirmation?
    /// A status.
    public init(isOn: Bool, isReady: Bool, pausedUntil: Date?, autoOffAt: Date?, displays: [DisplayStatus],
                banner: Banner?, symbol: StatusSymbolState, lastChange: LevelChange? = nil,
                pendingConfirmation: LevelConfirmation? = nil) {
        self.isOn = isOn; self.isReady = isReady; self.pausedUntil = pausedUntil; self.autoOffAt = autoOffAt
        self.displays = displays; self.banner = banner; self.symbol = symbol; self.lastChange = lastChange
        self.pendingConfirmation = pendingConfirmation
    }
    /// Before the engine started: off, not ready, no displays.
    public static let initial = BoostStatus(isOn: false, isReady: false, pausedUntil: nil, autoOffAt: nil,
                                            displays: [], banner: nil, symbol: .off)
}
