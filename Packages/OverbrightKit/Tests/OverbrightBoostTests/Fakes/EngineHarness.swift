// OverbrightBoostTests/Fakes/EngineHarness.swift — a BoostEngine over every Core fake, driven by a ManualTimeSource.
// ARCHITECTURE.md §9.1 (deterministic scenarios with fakes and the reference reducer), §10.6. Nothing here touches a
// display: FakeGammaPort, ScriptedHeadroom, FakeTriggerFactory and FakeSystemSignals only.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
@testable import OverbrightBoost

/// The engine and its fakes, plus helpers to advance time and read what the fakes saw.
@MainActor final class EngineHarness {
    let fixture: DisplayFixture
    let time = ManualTimeSource()
    let settings: SettingsStore
    let journal = RingBufferJournal(capacity: 5_000)
    let surfaces = OwnEDRSurfaces()
    let directory: FakeDisplayDirectory
    let signals = FakeSystemSignals()
    let gamma: FakeGammaPort
    let scripted: ScriptedHeadroom
    let headroom: RecordingHeadroom
    let triggers: FakeTriggerFactory
    /// What the engine gets: `triggers` behind the invariant-2 check.
    let checkedTriggers: OrderCheckingTriggers
    let conflicts = FakeConflictProbe()
    let engine: BoostEngine
    /// Every reduction's input, in order (tests inspect what the reducer saw).
    private(set) var inputs: [PolicyInput] = []

    /// The engine over `fixture` with the reference reducer (`tops` per display; the M4 Max Safe top otherwise), or
    /// with `decide` when given. `wrapGamma` puts a decorator (`CountingGammaPort`) between the engine and `gamma`;
    /// `defaults` backs the settings (`CountingDefaults` counts their writes). `asksToKeep` false (the default) switches
    /// "Keep this level?" off (`BoostEngine.keepPromptEnabled`), so a level change does not go back to Standard 10 s
    /// later (§4.9); `KeepPromptTests` and `KeepPromptTests` pass true.
    init(fixture: DisplayFixture = .builtinXDRLidOpen, reducer: ReferenceReducer = ReferenceReducer(),
         machine: MachineIdentity? = nil, decide: ((PolicyInput) -> PolicyDecision)? = nil,
         wrapGamma: (FakeGammaPort, ManualTimeSource) -> any GammaPort = { gamma, _ in gamma },
         defaults: UserDefaults = InMemoryDefaults(), asksToKeep: Bool = false) {
        self.fixture = fixture
        settings = SettingsStore(defaults: defaults)
        directory = FakeDisplayDirectory(fixture: fixture)
        gamma = FakeGammaPort(fixture: fixture, time: time)
        scripted = ScriptedHeadroom(fixture: fixture, time: time)
        headroom = RecordingHeadroom(scripted)
        triggers = FakeTriggerFactory(headroom: scripted)
        checkedTriggers = OrderCheckingTriggers(inner: triggers, gamma: gamma)
        let decision = decide ?? { reducer.decide($0) }
        weak var weakSelf: EngineHarness?
        engine = BoostEngine(settings: settings, machine: machine ?? fixture.machine, time: time, journal: journal,
                             ownEDRSurfaces: surfaces, displays: directory, signals: signals,
                             gamma: wrapGamma(gamma, time),
                             headroom: headroom, triggers: checkedTriggers, conflicts: conflicts,
                             reduce: { input in
                                 MainActor.assumeIsolated { weakSelf?.inputs.append(input) }
                                 return decision(input)
                             })
        weakSelf = self
        engine.watchdogEnabled = false
        engine.keepPromptEnabled = asksToKeep
        engine.launchArguments = LaunchArguments(["Overbright"])
        engine.pointerDisplay = { $0.first?.ref.key }
    }

    // MARK: Keys

    var builtIn: DisplayKey { DisplayFixture.Keys.builtIn }
    func id(_ key: DisplayKey) -> UInt32 { directory.facts(for: key)?.ref.id ?? 0 }

    // MARK: Driving

    /// Starts the engine (and turns it on).
    func start(on: Bool = false) async {
        await engine.start()
        if on { engine.setOn(true, source: .panel) }
        await settle()
    }

    /// Lets started tasks run without moving time.
    func settle(_ yields: Int = 40) async {
        for _ in 0..<yields { await Task.yield() }
    }

    /// Moves time by `duration` in steps of `step`, letting tasks run before each step.
    func advance(_ duration: Duration, step: Duration = .milliseconds(10), yields: Int = 25) async {
        await settle(yields)                                              // what the test just started runs first
        var left = duration
        while left > .zero {
            let next = min(step, left)
            await time.advance(by: next, yields: yields)                  // yields after every deadline and at the end
            left -= next
        }
    }

    /// Advances until `condition` holds (at most `limit`); returns whether it did.
    @discardableResult
    func advance(until condition: () -> Bool, limit: Duration = .seconds(30),
                 step: Duration = .milliseconds(10)) async -> Bool {
        var elapsed = Duration.zero
        await settle()
        while !condition() {
            guard elapsed < limit else { return false }
            await advance(step, step: step)
            elapsed += step
        }
        return true
    }

    /// Turns on and waits until `key` is boosted.
    @discardableResult
    func boost(_ key: DisplayKey? = nil, limit: Duration = .seconds(30)) async -> Bool {
        if !engine.status.isOn { engine.setOn(true, source: .panel) }
        let key = key ?? builtIn
        return await advance(until: { self.phase(key) == .boosted }, limit: limit)
    }

    // MARK: Reading

    func controller(_ key: DisplayKey? = nil) -> DisplayController? { engine.controllers[key ?? builtIn] }
    func phase(_ key: DisplayKey? = nil) -> EnginePhase? { engine.status.displays.first { $0.key == (key ?? builtIn) }?.phase }
    func displayStatus(_ key: DisplayKey? = nil) -> DisplayStatus? {
        engine.status.displays.first { $0.key == (key ?? builtIn) }
    }
    func table(_ key: DisplayKey? = nil) -> GammaTable? { gamma.table(of: id(key ?? builtIn)) }
    func base(_ key: DisplayKey? = nil) -> GammaTable? { gamma.base(of: id(key ?? builtIn)) }

    /// The factor of the live table over the display's base (1 at the base), measured at a mid entry.
    func liveFactor(_ key: DisplayKey? = nil) -> Double? {
        guard let table = table(key), let base = base(key) else { return nil }
        return Self.factor(of: table, over: base)
    }

    /// `table ÷ base` at the middle entry of the green channel.
    static func factor(of table: GammaTable, over base: GammaTable) -> Double? {
        let index = base.count / 2
        guard table.count == base.count, index > 0, base.green[index] > 0 else { return nil }
        return Double(table.green[index]) / Double(base.green[index])
    }

    /// Whether every display's live table equals its base.
    var everyTableAtBase: Bool {
        directory.displays.allSatisfy { facts in
            guard let table = gamma.table(of: facts.ref.id), let base = gamma.base(of: facts.ref.id) else { return true }
            return table.matches(base, tolerance: 1e-6)
        }
    }

    /// Our writes (not simulated foreign ones) to `key`.
    func writes(_ key: DisplayKey? = nil) -> [FakeGammaPort.Write] {
        gamma.writes.filter { !$0.isForeign && $0.display == id(key ?? builtIn) }
    }

    /// Journal codes in order.
    var codes: [String] { journal.snapshot().map(\.code) }

    /// Invariant 2 violations seen by the trigger wrapper (un-scale before removing a window).
    var orderViolations: [String] { checkedTriggers.violations }

    /// Invariant 1 (§9.1 property): every write above the base is backed by a reading of the same display at most
    /// 150 ms old with `G_written ≤ 0.97 × H` (G from the written factor in the encoded domain). One line per breach.
    func interlockViolations() -> [String] {
        var breaches: [String] = []
        let byDisplay = Dictionary(grouping: headroom.readings, by: \.display)   // each in time order
        for write in gamma.writes where !write.isForeign {
            guard let base = gamma.base(of: write.display),
                  let factor = Self.factor(of: write.table, over: base), factor > 1 + 1e-9 else { continue }
            let gain = FactorMath.lightGain(forTableFactor: factor, domain: .encoded)
            let readings = byDisplay[write.display] ?? []
            // The first reading at most 150 ms before the write (binary search), then every one up to the write.
            var low = 0, high = readings.count
            while low < high {
                let middle = (low + high) / 2
                if write.time - readings[middle].time > EngineTiming.readingMaxAge { low = middle + 1 } else { high = middle }
            }
            let backed = readings[low...].prefix { $0.time <= write.time }.contains { reading in
                gain <= FactorMath.headroomMargin * reading.current + 1e-5   // Float32 tables
            }
            if !backed { breaches.append("display \(write.display) at \(write.time.sinceOrigin): G \(gain)") }
        }
        return breaches
    }

    /// Live trigger windows on `key`.
    func liveTriggers(_ key: DisplayKey? = nil) -> [FakeTriggerHandle] { triggers.liveTriggers(on: key ?? builtIn) }

    /// Stores preferences of `key`.
    func setPreferences(_ key: DisplayKey? = nil, _ change: (inout DisplayPreferences) -> Void) {
        var all = settings[DisplaySettings.perDisplay]
        var preferences = all[key ?? builtIn] ?? DisplayPreferences()
        change(&preferences)
        all[key ?? builtIn] = preferences
        settings[DisplaySettings.perDisplay] = all
    }
}
