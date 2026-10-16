// OverbrightCore/Model/System/SystemSnapshot.swift — everything the policy needs from the system. ARCHITECTURE.md §3.3, §7.1.

/// Everything the policy needs from the system, published by `SystemSignals`.
public nonisolated struct SystemSnapshot: Hashable, Sendable {
    /// Power source, battery and Low Power Mode.
    public var power: PowerState
    /// The thermal state.
    public var thermal: ThermalLevel
    /// The lock screen is up.
    public var isScreenLocked: Bool
    /// The screensaver runs.
    public var isScreensaverRunning: Bool
    /// The displays sleep.
    public var areDisplaysAsleep: Bool
    /// The system is going to sleep or sleeps.
    public var isSystemSleeping: Bool
    /// Our session is on the console (`CGSessionCopyCurrentDictionary`[`kCGSessionOnConsoleKey`] at launch, then
    /// session resign/become-active). False → no table write and no launch rescue at all (§7.4).
    public var isSessionActive: Bool
    /// The frontmost app, if any.
    public var frontmost: FrontmostApp?
    /// Displays that show a full-screen window (any owner except us), after the 0.6 s debounce.
    public var fullScreenDisplays: Set<DisplayKey>
    /// Subset of `fullScreenDisplays` whose full-screen window's owner holds a display-sleep assertion (video).
    public var fullScreenVideoDisplays: Set<DisplayKey>
    /// System idle time has passed the OLED idle threshold (sampled at deadlines, never polled while off).
    public var isIdleBeyondThreshold: Bool
    /// A camera is in use somewhere (CoreMediaIO).
    public var isCameraInUse: Bool
    /// Accessibility ▸ Reduce Motion.
    public var reduceMotion: Bool
    /// Running apps that matched the conflict catalogue.
    public var conflicts: [ConflictingApp]
    /// The Focus filter's directive.
    public var focus: FocusDirective
    /// macOS 26+ asked apps to suppress HDR content (logged; shown as a reason, never escalated against).
    public var isHDRSuppressed: Bool
    /// A snapshot; everything but `power` defaults to a quiet, unlocked, active session.
    public init(power: PowerState, thermal: ThermalLevel = .nominal, isScreenLocked: Bool = false,
                isScreensaverRunning: Bool = false, areDisplaysAsleep: Bool = false, isSystemSleeping: Bool = false,
                isSessionActive: Bool = true, frontmost: FrontmostApp? = nil, fullScreenDisplays: Set<DisplayKey> = [],
                fullScreenVideoDisplays: Set<DisplayKey> = [], isIdleBeyondThreshold: Bool = false,
                isCameraInUse: Bool = false, reduceMotion: Bool = false, conflicts: [ConflictingApp] = [],
                focus: FocusDirective = .leaveAlone, isHDRSuppressed: Bool = false) {
        self.power = power; self.thermal = thermal; self.isScreenLocked = isScreenLocked
        self.isScreensaverRunning = isScreensaverRunning; self.areDisplaysAsleep = areDisplaysAsleep
        self.isSystemSleeping = isSystemSleeping; self.isSessionActive = isSessionActive; self.frontmost = frontmost
        self.fullScreenDisplays = fullScreenDisplays; self.fullScreenVideoDisplays = fullScreenVideoDisplays
        self.isIdleBeyondThreshold = isIdleBeyondThreshold; self.isCameraInUse = isCameraInUse
        self.reduceMotion = reduceMotion; self.conflicts = conflicts; self.focus = focus
        self.isHDRSuppressed = isHDRSuppressed
    }
    /// The screen cannot be seen: lock shield, screensaver, sleep, or another session on the console.
    public var isShielded: Bool {
        isScreenLocked || isScreensaverRunning || areDisplaysAsleep || isSystemSleeping || !isSessionActive
    }
}
