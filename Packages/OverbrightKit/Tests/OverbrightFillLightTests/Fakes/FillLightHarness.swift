// OverbrightFillLightTests/Fakes/FillLightHarness.swift — a FillLightController over Core fakes, a manual clock and the
// recording surface factory (ARCHITECTURE.md §9.1: ManualTimeSource, never a short real-time wait).
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightFillLight

/// The main display's ID as the test sets it.
@MainActor final class MainDisplayBox {
    var id: CGDirectDisplayID = 1
}

/// Records what the announcer posts.
@MainActor final class AnnouncementLog {
    private(set) var texts: [String] = []
    func append(_ text: String) { texts.append(text) }
}

/// The controller and every port it talks to, wired with fakes. Settings live in memory.
@MainActor final class FillLightHarness {
    let settings = SettingsStore(defaults: InMemoryDefaults())
    let time = ManualTimeSource()
    let directory: FakeDisplayDirectory
    let headroom: ScriptedHeadroom
    let signals = FakeSystemSignals()
    let ownEDRSurfaces = OwnEDRSurfaces()
    let journal = RingBufferJournal()
    let factory = FakeFillLightSurfaces()
    let announcements = AnnouncementLog()
    /// What the controller's `mainDisplayID` returns.
    var mainDisplayID: CGDirectDisplayID {
        get { mainDisplay.id }
        set { mainDisplay.id = newValue }
    }
    let controller: FillLightController
    private let mainDisplay = MainDisplayBox()

    /// A harness over `fixture` (or `displays` with idle headroom scripts), not started. `timing` defaults to the
    /// raw-signal `.standard` delays the rule tests script; nil keeps the controller's own default.
    init(fixture: DisplayFixture = .builtinXDRLidOpen, displays: [DisplayFacts]? = nil,
         timing: FillLightRule.Timing? = .standard) {
        if let displays {
            directory = FakeDisplayDirectory(displays: displays)
            let scripts = Dictionary(uniqueKeysWithValues: displays.map {
                ($0.ref.key, HeadroomScript(potential: 16, grant: 2.5))
            })
            headroom = ScriptedHeadroom(time: time, scripts: scripts)
        } else {
            directory = FakeDisplayDirectory(fixture: fixture)
            headroom = ScriptedHeadroom(fixture: fixture, time: time)
        }
        let log = announcements, main = mainDisplay
        let announcer = Announcer(post: { log.append($0) }, now: { 0 })
        if let timing {
            controller = FillLightController(
                settings: settings, displays: directory, headroom: headroom, signals: signals,
                ownEDRSurfaces: ownEDRSurfaces, time: time, journal: journal, announcer: announcer, surfaces: factory,
                cameraTiming: timing, mainDisplayID: { main.id })
        } else {
            controller = FillLightController(
                settings: settings, displays: directory, headroom: headroom, signals: signals,
                ownEDRSurfaces: ownEDRSurfaces, time: time, journal: journal, announcer: announcer, surfaces: factory,
                mainDisplayID: { main.id })
        }
    }

    /// Starts the controller and lets its first observation pass run.
    func start() async {
        await controller.start()
        await settle()
    }

    /// Lets observation callbacks and woken tasks run without moving the clock.
    func settle() async { await time.advance(by: .zero) }

    /// Moves the clock (waking the rule's and the settle reads' sleeps on the way). Settles first: a task the
    /// controller just created starts, and so registers its sleep, only on a later turn of the main actor.
    func advance(_ duration: Duration) async {
        await settle()
        await time.advance(by: duration)
    }

    /// Journal codes in order.
    var journalCodes: [String] { journal.snapshot().map(\.code) }

    /// The one live surface's last style.
    var style: FillLightStyle? { factory.current?.style }
}

/// A display for tests that need layouts the fixtures do not have (two externals, a mirror member, …).
func testDisplay(_ id: CGDirectDisplayID, builtIn: Bool = false, mirrored: Bool = false) -> DisplayFacts {
    DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: String(format: "0B21E7F1-0000-4000-8000-0000000000%02X", id)), id: id),
                 name: "Display \(id)", isBuiltIn: builtIn, isMirrored: mirrored, gammaCapacity: 1024,
                 panelClass: builtIn ? .builtInXDR : .hdrExternal)
}
