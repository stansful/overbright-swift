// OverbrightCore/Model/Policy/PolicySettings.swift — the settings the reducer reads. ARCHITECTURE.md §3.4, §3.8, D10.

/// The settings the reducer reads, flattened from the keys catalog (§3.8) by the engine.
public nonisolated struct PolicySettings: Hashable, Sendable {
    /// The battery automation.
    public var batteryGuard: BatteryGuard
    /// Percent, 5…95.
    public var batteryThreshold: Int
    /// Pause extra brightness in Low Power Mode.
    public var pauseInLowPowerMode: Bool
    /// Full-screen window AND its owner holds a display-sleep assertion (default on, beta until H-P1).
    public var pauseForFullScreenVideo: Bool
    /// Any full-screen window, documents and games included (default off).
    public var pauseForAllFullScreen: Bool
    /// Pause while a game is frontmost.
    public var pauseInGames: Bool
    /// Master switch of `pausedApps`.
    public var pauseForListedApps: Bool
    /// The per-app pause list.
    public var pausedApps: [PausedAppRule]
    /// Allowed hours; nil = always.
    public var schedule: ScheduleWindow?
    /// "Same level on all displays".
    public var linkLevels: Bool
    /// The level every display uses while `linkLevels` is on.
    public var linkedLevel: LevelPosition
    /// Taper extra brightness towards ×1 as the user lowers system brightness (§5.4, default on).
    public var boostOnlyNearFullBrightness: Bool
    /// Conflict entries the user always continues with (S2/S3).
    public var alwaysContinueEntryIDs: Set<String>
    /// Settings with the defaults of §3.8.
    public init(batteryGuard: BatteryGuard = .belowThreshold, batteryThreshold: Int = 20, pauseInLowPowerMode: Bool = true,
                pauseForFullScreenVideo: Bool = true, pauseForAllFullScreen: Bool = false, pauseInGames: Bool = false,
                pauseForListedApps: Bool = true, pausedApps: [PausedAppRule] = [], schedule: ScheduleWindow? = nil,
                linkLevels: Bool = false, linkedLevel: LevelPosition = LevelPreset.brightRoom.position,
                boostOnlyNearFullBrightness: Bool = true, alwaysContinueEntryIDs: Set<String> = []) {
        self.batteryGuard = batteryGuard; self.batteryThreshold = batteryThreshold
        self.pauseInLowPowerMode = pauseInLowPowerMode; self.pauseForFullScreenVideo = pauseForFullScreenVideo
        self.pauseForAllFullScreen = pauseForAllFullScreen; self.pauseInGames = pauseInGames
        self.pauseForListedApps = pauseForListedApps; self.pausedApps = pausedApps; self.schedule = schedule
        self.linkLevels = linkLevels; self.linkedLevel = linkedLevel
        self.boostOnlyNearFullBrightness = boostOnlyNearFullBrightness
        self.alwaysContinueEntryIDs = alwaysContinueEntryIDs
    }
}
