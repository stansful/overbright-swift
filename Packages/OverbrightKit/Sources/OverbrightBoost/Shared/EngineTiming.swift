// OverbrightBoost/Shared/EngineTiming.swift — every timing and threshold constant of the engine, named once.
// ARCHITECTURE.md §4.4 (the table this file mirrors), D5, D6, D7, D9. Shared between WP4 and WP5 and owned by the
// contract owner (§10.0); WP16 tunes the values after the hardware session and records each change in the changelog.
// Pure constants: no state, no clocks.

/// Timings and thresholds of the per-display engine (ARCHITECTURE.md §4.4). Every value is used by name, never as a
/// literal elsewhere.
public nonisolated enum EngineTiming {
    // MARK: Gate (D6)

    /// Idle headroom H0 is the highest of this many reads …
    public static let baselineReads = 3
    /// … taken this far apart.
    public static let baselineReadInterval: Duration = .milliseconds(100)
    /// Headroom poll while arming, gating or in a poll burst.
    public static let gatePollInterval: Duration = .milliseconds(100)
    /// Movement: H ≥ H0 + this.
    public static let movementThreshold = 0.05
    /// Pre-held: H0 ≥ max(this, G ÷ 0.97) …
    public static let preHeldMinimum = 1.3
    /// … or H0 ≥ this and stable over the baseline reads (or an own EDR surface on the display).
    public static let preHeldStable = 1.25
    /// A rung escalates this long after its first successful present without movement.
    public static let rungTimeout: Duration = .milliseconds(2500)
    /// Ready (normal path): H ≥ max(this, H0 + `readyAboveIdle`); pre-held path: H ≥ this.
    public static let readyMinimum = 1.1
    /// See `readyMinimum`.
    public static let readyAboveIdle = 0.1
    /// Stable: within ± this …
    public static let stabilityBand = 0.05
    /// … over this window.
    public static let stabilityWindow: Duration = .milliseconds(1500)
    /// A gate that is not stable this long after the first movement (pre-held: after arming) fails its rung.
    public static let gateTimeout: Duration = .seconds(12)

    // MARK: Interlock and raises (D5, §5.4, §5.7)

    /// `TableWriter` refuses readings older than this (`TimeSource.now − reading.time`).
    public static let readingMaxAge: Duration = .milliseconds(150)
    /// A headroom-recovery raise needs a target at least this many times the applied gain (user raises do not).
    public static let raiseHysteresis = 1.05
    /// Poll burst while a raise waits for headroom: this interval …
    public static let pollBurstInterval: Duration = .milliseconds(100)
    /// … for at most this long.
    public static let pollBurstLimit: Duration = .seconds(3)

    // MARK: Ramps and flicker safety (D5, §5.7, §5.8)

    /// User, policy and every reapply.
    public static let rampDuration: Duration = .milliseconds(300)
    /// The same under Reduce Motion (never a snap).
    public static let rampDurationReduceMotion: Duration = .milliseconds(160)
    /// Back to Standard.
    public static let rampDurationBackToStandard: Duration = .milliseconds(120)
    /// Ramp steps per second (smoothstep in stops).
    public static let rampStepsPerSecond = 60
    /// A ramp never has fewer steps.
    public static let minimumRampSteps = 6
    /// No two opposing transitions on one display closer than this.
    public static let minimumOpposingInterval: Duration = .milliseconds(500)
    /// This many non-user reversals …
    public static let oscillationTripReversals = 4
    /// … within this window trip the display (monotonic headroom tracking excluded).
    public static let oscillationWindow: Duration = .seconds(10)

    // MARK: Drift check and repairs (D9, §4.8)

    /// Drift check interval while scaled or dimmed.
    public static let watchdogInterval: Duration = .seconds(2)
    /// Drift check this long after any app terminated while scaled or dimmed.
    public static let appTerminationCheckDelay: Duration = .milliseconds(50)
    /// Read-back tolerance at the sample index.
    public static let driftTolerance = 0.01
    /// Hypotheses must be at least this many tolerances apart to be told apart.
    public static let driftSeparationFactor = 2.0
    /// This many repairs …
    public static let repairBudget = 3
    /// … within this window trip the display.
    public static let repairWindow: Duration = .seconds(6)
    /// An adoption counts as a base change only within this long after a ColorSync, reconfiguration or accessibility
    /// event.
    public static let adoptionWindow: Duration = .seconds(2)
    /// More than this many unexplained adoptions …
    public static let adoptionBudget = 2
    /// … within this window trip the display as a foreign writer.
    public static let adoptionBudgetWindow: Duration = .seconds(60)
    /// After an event, wait until a read differs from our last write, at most this long.
    public static let reapplyWaitLimit: Duration = .seconds(1)
    /// A reset is reapplied this long after it was seen.
    public static let resetReapplyDelay: Duration = .milliseconds(250)

    // MARK: Events, suspension and backoff (D9, §4.3, §4.7)

    /// A suspended display keeps its trigger this long.
    public static let triggerLinger: Duration = .seconds(10)
    /// The re-reduction a screen-parameters notification asks for runs on the trailing edge of this interval, at most
    /// once per interval (macOS posts one per frame while headroom moves, up to 122/s). Coalescing only: the headroom
    /// check and its safety drop stay synchronous in the event handler (D5, §4.3), and any other reduction runs at once.
    public static let screenParametersReduceInterval: Duration = .milliseconds(100)
    /// Wait after wake or lid open before re-arming.
    public static let wakeSettle: Duration = .seconds(1)
    /// Backoff of the cached rung while headroom refuses after a wake or unlock (never escalating).
    public static let wakeBackoff: [Duration] = [.seconds(1), .seconds(3), .seconds(10), .seconds(30)]
    /// Failures within this long after a wake or unlock do not count against a cached rung.
    public static let escalationQuarantine: Duration = .seconds(60)

    // MARK: Safety (D7)

    /// The hang watchdog pings the main thread this often while a display is scaled …
    public static let hangPing: Duration = .seconds(2)
    /// … and fires when a ping has had no answer for this long.
    public static let hangTimeout: Duration = .seconds(3)
    /// Quit waits this long for the ramped stop.
    public static let quitTimeout: Duration = .seconds(1)
    /// A TERM/INT/HUP waits this long for the main-actor stop.
    public static let signalStopTimeout: Duration = .seconds(1)

    // MARK: Levels, pauses and the HUD (§4.9, D10, D19)

    /// "Keep this level?" goes back to Standard after this long without an answer (counted from the last step).
    public static let lowLevelConfirmTimeout: Duration = .seconds(10)
    /// Levels set by a drag, steps or presets reach UserDefaults this long after the last change (every reader sees
    /// them at once), and at once on stop, quit and every turn-off. Settings only: no safety state waits for it.
    public static let levelPersistDelay: Duration = .milliseconds(500)
    /// An icon, shortcut or intent turn-on not ready this long after the request shows "Preparing…".
    public static let preparingDelay: Duration = .milliseconds(500)
    /// A status change of minor fields only (readings, which place the allowed-now marker, and the applied gain while a
    /// ramp runs) is published at most this often, on the trailing edge (DESIGN.md §17: the marker ≤ 4 Hz); any other
    /// change publishes at once. The engine never reads its status, so no decision or safety write waits for it.
    public static let minorPublishInterval: Duration = .milliseconds(250)
}
