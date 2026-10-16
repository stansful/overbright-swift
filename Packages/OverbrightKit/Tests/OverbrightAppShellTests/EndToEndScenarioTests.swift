// OverbrightAppShellTests/EndToEndScenarioTests.swift — every fixture of ARCHITECTURE.md §3.9 through the whole app as
// `make run` wires it under `--qa-simulate`: the composition root's simulated ports, the real engine and Policy, Fill
// Light, shortcuts and the publish point, the launch check and the ordered services, driven by the same
// `ScenarioScript` the QA matrix passes as `--qa-script`. Each `dump` is what the menu bar symbol, the banner and each
// card's chip show (Design's English copy, chosen as the panel chooses it), checked against DESIGN.md §4.1 (symbol),
// §12.2 (chips) and §12.3 (banners). §10.15.
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightIntents
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct EndToEndScenarioTests {
    // MARK: Running a scenario

    /// Runs `script` over `fixture` on a manual clock; returns the dumps by label.
    static func run(_ fixture: DisplayFixture, _ script: String) async throws -> [String: StatusSummary] {
        let time = ManualTimeSource()
        let shell = TestShell.shell(fixture, context: TestShell.context(fixture: fixture, time: time))
        await CompositionRoot.runLaunchWork(shell)
        let rig = try #require(ScenarioRunner.Rig(shell: shell))
        let runner = ScenarioRunner(rig: rig, wait: { duration in await advance(time, by: duration) })
        try await runner.run(ScenarioScript.parse(script))
        shell.runner.stopNow()
        return Dictionary(runner.summaries.map { ($0.label, $0) }) { _, last in last }
    }

    /// Moves `time` in 10 ms steps, letting the woken tasks run before each step.
    static func advance(_ time: ManualTimeSource, by duration: Duration) async {
        var left = duration
        while left > .zero {
            for _ in 0..<10 { await Task.yield() }
            let step = min(left, .milliseconds(10))
            await time.advance(by: step)
            left -= step
        }
    }

    // MARK: Expectations

    /// A card's chip and coarse state.
    typealias Card = (chip: String?, state: String)

    /// What one dump must show: the symbol, the banner and, per display role, the chip and a coarse state.
    struct Expect {
        let symbol: String
        let banner: String?
        let displays: [String: Card]

        init(_ symbol: String, _ banner: String? = nil, _ displays: [String: Card]) {
            self.symbol = symbol; self.banner = banner; self.displays = displays
        }
    }

    /// The coarse state of a card: boosted, dimmed, suspended, failed, preparing or idle.
    static func state(_ display: StatusSummary.Display) -> String {
        for state in ["boosted", "dimmed", "suspended", "failed"] where display.phase.hasPrefix(state) { return state }
        if display.phase.hasPrefix("arming") || display.phase.hasPrefix("gating") { return "preparing" }
        return "idle"
    }

    static func check(_ dumps: [String: StatusSummary], _ expected: [String: Expect], _ fixture: DisplayFixture,
                      sourceLocation: SourceLocation = #_sourceLocation) {
        for (label, expect) in expected {
            guard let dump = dumps[label] else {
                Issue.record("\(fixture.rawValue): no dump \(label)", sourceLocation: sourceLocation)
                continue
            }
            let at = "\(fixture.rawValue) at \(label)"
            #expect(dump.symbol == expect.symbol, "\(at): symbol", sourceLocation: sourceLocation)
            #expect(dump.banner == expect.banner, "\(at): banner", sourceLocation: sourceLocation)
            for (role, card) in expect.displays {
                let display = dump.displays.first { $0.display == role }
                #expect(display?.chip == card.chip, "\(at): \(role) chip", sourceLocation: sourceLocation)
                #expect(display.map(state) == card.state, "\(at): \(role) state", sourceLocation: sourceLocation)
            }
        }
    }

    static let lowPower = "Paused because Low Power Mode is on."
    static let booster = "Paused because \u{2068}QA booster\u{2069} also changes display brightness. Quit it, or use "
        + "Compatibility mode, which works alongside it."
    static let heat = "Paused because your Mac is hot. Overbright continues when it cools down."
    static let onLabels = ["on", "low-power", "resumed", "locked", "unlocked", "booster", "clear"]

    /// The standard scenario: on, a guard, a shield, a booster, dimming, off.
    static let standard = """
        on; wait 8; dump on; low-power on; wait 1; dump low-power; low-power off; wait 8; dump resumed; \
        lock; wait 0.1; dump locked; unlock; wait 8; dump unlocked; conflict booster; wait 1; dump booster; \
        conflict none; wait 8; dump clear; level -0.5; wait 1; dump dimmed; off; wait 1; dump off
        """

    /// The standard scenario's expectations for a display `role` that boosts, plus `others` per label.
    static func boosting(_ role: String, others: [String: [String: Card]] = [:]) -> [String: Expect] {
        let rows: [(String, String, String?, Card)] = [
            ("on", "on", nil, (nil, "boosted")), ("low-power", "paused", lowPower, (nil, "idle")),
            ("resumed", "on", nil, (nil, "boosted")), ("locked", "paused", nil, (nil, "suspended")),
            ("unlocked", "on", nil, (nil, "boosted")), ("booster", "attention", booster, (nil, "idle")),
            ("clear", "on", nil, (nil, "boosted")), ("dimmed", "dimming", nil, (nil, "dimmed")),
            ("off", "off", nil, (nil, "idle")),
        ]
        return Dictionary(uniqueKeysWithValues: rows.map { label, symbol, banner, card in
            (label, Expect(symbol, banner, [role: card].merging(others[label] ?? [:]) { first, _ in first }))
        })
    }

    /// The standard scenario's expectations for a display that does not boost: `chip` while on (except at
    /// `quietLabels`), no banner (it would not change), the dim half working (`dimmedChip` while dimmed).
    static func notBoosting(_ role: String, chip: String, dimmedChip: String?,
                            quietLabels: Set<String> = []) -> [String: Expect] {
        var expected: [String: Expect] = [:]
        for label in onLabels { expected[label] = Expect("on", nil, [role: (quietLabels.contains(label) ? nil : chip, "idle")]) }
        expected["dimmed"] = Expect("dimming", nil, [role: (dimmedChip, "dimmed")])
        expected["off"] = Expect("off", nil, [role: (nil, "idle")])
        return expected
    }

    /// `card` for every label the master is on at, `dimmed` while dimmed, no chip once off.
    static func others(_ role: String, _ card: Card, dimmed: Card) -> [String: [String: Card]] {
        var others = Dictionary(uniqueKeysWithValues: onLabels.map { ($0, [role: card]) })
        others["dimmed"] = [role: dimmed]
        others["off"] = [role: (nil, "idle")]
        return others
    }

    // MARK: Every fixture

    @Test(arguments: DisplayFixture.allCases)
    func everyFixtureShowsTheRightSymbolBannerAndChips(_ fixture: DisplayFixture) async throws {
        let dumps = try await Self.run(fixture, Self.standard)
        let expected: [String: Expect]
        switch fixture {
        case .builtinXDRLidOpen, .calibratedProfile, .neoIgnoresWrites:
            expected = Self.boosting("built-in")
        case .proDisplayXDR:
            expected = Self.boosting("pro")
        case .sidecar:
            // Sidecar sits in the "Why?" row: no card, so no chip.
            expected = Self.boosting("built-in", others: Self.others("sidecar", (nil, "idle"), dimmed: (nil, "idle")))
        case .hardwareMirror:
            expected = Self.boosting("built-in", others: Self.others("projector", ("Mirrored", "idle"),
                                                                      dimmed: ("Mirrored", "dimmed")))
        case .russianNames:
            // The same verdicts as with English names (D8: no name logic): the built-in boosts, the OLED is opt-in.
            expected = Self.boosting("built-in", others: Self.others("msi", ("Extra brightness off", "idle"),
                                                                      dimmed: (nil, "dimmed")))
        case .mpg322uxHDROn:
            expected = Self.notBoosting("msi", chip: "Extra brightness off", dimmedChip: nil)
        case .mpg322uxHDROff:
            expected = Self.notBoosting("msi", chip: "HDR is off", dimmedChip: "HDR is off")
        case .lcdOnly:
            expected = Self.notBoosting("built-in", chip: "Not supported", dimmedChip: "Not supported")
        case .studioDisplayXDR:
            // Safe adds nothing there (§12.1): a Safe limit chip, and nothing that would pause it.
            expected = Self.notBoosting("studio", chip: "Safe limit", dimmedChip: nil,
                                        quietLabels: ["low-power", "locked", "booster"])
        case .builtinXDRPreset600:
            // The preset limits HDR and macOS grants no headroom: Preparing… while the ladder climbs.
            var preset = Self.boosting("built-in")
            for label in ["on", "resumed", "unlocked", "clear"] {
                preset[label] = Expect("preparing", nil, ["built-in": ("Preparing…", "preparing")])
            }
            expected = preset
        }
        Self.check(dumps, expected, fixture)
        // Nothing stays open after off, and the counters are the fakes' (no real display is ever touched).
        #expect(dumps["off"]?.triggerWindows == 0, "\(fixture.rawValue)")
        if fixture == .neoIgnoresWrites {
            #expect(dumps.values.allSatisfy { $0.gammaWrites == 0 }, "Compatibility mode writes no table")
            #expect(dumps["on"]?.triggerWindows == 1 && dumps["dimmed"]?.triggerWindows == 1, "the overlay dims too")
        }
    }

    // MARK: Guards, automations, shields and levels

    @Test func guardsAndAutomationsOnTheBuiltIn() async throws {
        let script = """
            on; wait 8; dump on; thermal serious; wait 3; dump warm; thermal critical; wait 1; dump hot; \
            thermal nominal; wait 8; dump cool; battery 15; wait 1; dump battery; battery adapter; wait 8; dump adapter; \
            focus off; wait 1; dump focus-off; focus leave; wait 8; dump focus-leave; full-screen video built-in; \
            wait 1; dump video; full-screen none; wait 8; dump no-video; conflict writer; wait 1; dump writer; \
            conflict conditional; wait 8; dump conditional; conflict none; pause 600; wait 1; dump paused; resume; \
            wait 8; dump resumed; screensaver on; wait 0.1; dump screensaver; screensaver off; wait 8; dump back; \
            sleep; wait 0.1; dump asleep; wake; wait 10; dump awake; brighter; wait 1; dump brighter; level max; \
            wait 2; dump max; standard; wait 1; dump standard
            """
        let dumps = try await Self.run(.builtinXDRLidOpen, script)
        let boosted: Card = (nil, "boosted")
        let idle: Card = (nil, "idle")
        let writer = "Paused because \u{2068}QA gammaWriter\u{2069} changes display colors. Night Shift gives warm light "
            + "without a conflict."
        Self.check(dumps, [
            "on": Expect("on", nil, ["built-in": boosted]),
            "warm": Expect("on", nil, ["built-in": ("Limited by heat", "boosted")]),
            "hot": Expect("paused", Self.heat, ["built-in": idle]),
            "cool": Expect("on", nil, ["built-in": boosted]),
            "adapter": Expect("on", nil, ["built-in": boosted]),
            "focus-off": Expect("paused", "Off because of the current Focus.", ["built-in": idle]),
            "focus-leave": Expect("on", nil, ["built-in": boosted]),
            "video": Expect("paused", nil, ["built-in": ("Paused: video", "idle")]),
            "no-video": Expect("on", nil, ["built-in": boosted]),
            "writer": Expect("attention", writer, ["built-in": idle]),
            "conditional": Expect("on", nil, ["built-in": ("\u{2068}QA conditional\u{2069} may interfere", "boosted")]),
            "resumed": Expect("on", nil, ["built-in": boosted]),
            "screensaver": Expect("paused", nil, ["built-in": (nil, "suspended")]),
            "back": Expect("on", nil, ["built-in": boosted]),
            "asleep": Expect("paused", nil, ["built-in": (nil, "suspended")]),
            "awake": Expect("on", nil, ["built-in": boosted]),
            "max": Expect("on", nil, ["built-in": ("Safe limit", "boosted")]),
            "standard": Expect("off", nil, ["built-in": idle]),
        ], .builtinXDRLidOpen)
        // The battery and pause banners carry a number and a time in the user's format.
        #expect(dumps["battery"]?.symbol == "paused")
        #expect(dumps["battery"]?.banner?.hasPrefix("Paused because the battery is below 20") == true)
        #expect(dumps["paused"]?.symbol == "paused")
        #expect(dumps["paused"]?.banner?.hasPrefix("Overbright is paused until ") == true)
        // Heat caps at ×1.2; Brighter steps up; Max stops at the Safe top (×1.67 on the 1600-nit preset).
        let gain = { (label: String) in dumps[label]?.displays.first?.applied ?? 0 }
        #expect(gain("warm") == 1.2)
        #expect(gain("brighter") > gain("awake"))
        #expect(abs(gain("max") - 1000.0 / 600) < 0.01)
    }

    /// An opt-in OLED external: once its switch is on it boosts within the OLED limit, and guards pause it.
    @Test func anOLEDBoostsOnceTurnedOn() async throws {
        let dumps = try await Self.run(.mpg322uxHDROn, """
            on; boost msi on; wait 10; dump enabled; low-power on; wait 1; dump low-power; low-power off; level max; \
            wait 10; dump max
            """)
        Self.check(dumps, [
            "enabled": Expect("on", nil, ["msi": (nil, "boosted")]),
            "low-power": Expect("paused", Self.lowPower, ["msi": (nil, "idle")]),
            "max": Expect("on", nil, ["msi": ("OLED limit", "boosted")]),
        ], .mpg322uxHDROn)
        #expect(dumps["max"]?.displays.first?.applied == 1.3)
    }

    /// A preset that never grants headroom ends in "No extra range" once the ladder ran out, with every trigger gone.
    @Test func aDisplayThatNeverGetsHeadroomSaysSo() async throws {
        let dumps = try await Self.run(.builtinXDRPreset600, "on; wait 40; dump failed")
        Self.check(dumps, ["failed": Expect("on", nil, ["built-in": ("No extra range", "failed")])], .builtinXDRPreset600)
        #expect(dumps["failed"]?.triggerWindows == 0 && dumps["failed"]?.gammaWrites == 0)
    }

    // MARK: Shortcuts, intents and Settings reach the engine

    @Test func shortcutsIntentsAndSettingsReachTheEngine() async throws {
        let time = ManualTimeSource()
        let hotKeys = RecordingHotKeys()
        let shell = TestShell.shell(context: TestShell.context(time: time), hotKeys: hotKeys)
        await CompositionRoot.runLaunchWork(shell)
        let boost = shell.services.boost
        let combo = { (id: ShortcutID) in ShortcutCatalog.all.first { $0.id == id }?.defaultCombo }
        // ⌃⌥⌘B turns it on, as a shortcut (the HUD shows shortcut changes); ⌃⌥⌘0 is Back to Standard.
        #expect(hotKeys.press(try #require(combo(.toggle))))
        #expect(boost.status.isOn && boost.status.lastChange?.source == .shortcut)
        await Self.advance(time, by: .seconds(8))
        #expect(boost.status.displays.first?.phase == .boosted)
        let engine = try #require(shell.engine)
        #expect(!engine.strategyCache.records.isEmpty)                     // the winning rung was learned
        #expect(hotKeys.press(try #require(combo(.standard))))
        await Self.advance(time, by: .seconds(1))
        #expect(!boost.status.isOn && boost.status.displays.first?.appliedGain == 1)
        // The App Intents router, connected as the app delegate connects it.
        let router = IntentRouter(time: time)
        router.connect(boost: boost, displays: shell.services.displays, signals: shell.services.signals)
        try await router.turnOn()
        #expect(boost.status.isOn && boost.status.lastChange?.source == .intent)
        try await router.turnOff()
        // Settings ▸ Advanced ▸ Forget Learned Methods reaches the real engine.
        boost.forgetLearnedMethods()
        #expect(engine.strategyCache.records.isEmpty)
        shell.runner.stopNow()
    }
}
