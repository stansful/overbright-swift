// OverbrightAppShellTests/CalibrationWindowTests.swift — the calibration window (ARCHITECTURE.md §7.6; DESIGN.md §9):
// it asks the engine for a session for its display, covers that display's screen borderless at `.screenSaver − 1` in
// the screen's colour space, and Esc or closing it ends the session at once. A simulated display always gets an
// ordinary titled window and is never matched to a real screen, even when its fixture ID equals a real screen's number;
// a real display without a screen of its own begins no session and says it can't be calibrated now (WP14). A test
// never orders the window in: `preparedWindow(for:)` builds what `show` brings forward.
import AppKit
import Foundation
import Observation
import OverbrightCore
import OverbrightDesign
import OverbrightSettingsUI
import SwiftUI
import Testing
@testable import OverbrightAppShell

/// A session whose calls the test reads.
@MainActor @Observable private final class RecordingSession: CalibrationSession {
    let display: DisplayKey
    var currentFactor: Double = 1
    var headroom: Double? = 2.667
    var isSweepPausedAtLimit = false
    var state: CalibrationState = .ready
    private(set) var calls: [String] = []
    init(display: DisplayKey) { self.display = display }
    func showComparison(boosted: Bool) { calls.append("showComparison") }
    func startSweep() { calls.append("startSweep") }
    func continueSweep() { calls.append("continueSweep") }
    func markMerged() { calls.append("markMerged") }
    func showLinearConfirmation() { calls.append("showLinearConfirmation") }
    func answerLinearConfirmation(distinguishable: Bool) { calls.append("answer") }
    func setMeasuredSDRWhite(nits: Double?) { calls.append("sdrWhite") }
    func finish(brighter: Bool?) -> CalibrationRecord? { calls.append("finish"); state = .finished; return nil }
    func cancel() { calls.append("cancel"); state = .aborted(.cancelled) }
}

/// The preview engine, with calibration sessions.
@MainActor @Observable private final class CalibratingBoost: BoostControl {
    let preview: PreviewBoostControl
    private(set) var sessions: [RecordingSession] = []
    var status: BoostStatus { preview.status }
    init(fixture: DisplayFixture) { preview = PreviewBoostControl(fixture: fixture) }
    func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? {
        let session = RecordingSession(display: display)
        sessions.append(session)
        return session
    }
    func setOn(_ on: Bool, source: ControlSource) { preview.setOn(on, source: source) }
    func toggle(source: ControlSource) { preview.toggle(source: source) }
    func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource) {}
    func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource) {}
    func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource) {}
    func step(_ direction: StepDirection, source: ControlSource) {}
    func toggleDim(source: ControlSource) {}
    func returnToStandard(source: ControlSource) {}
    func keepLowLevel() {}
    func revertLowLevel() {}
    func pause(until deadline: Date?, source: ControlSource) {}
    func resume(source: ControlSource) {}
    func continueAnyway(_ app: ConflictingApp) {}
    func retry(_ display: DisplayKey) {}
    func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport { await preview.runSelfTest(options) }
    func rescueDisplayColors() async -> RescueOutcome { .alreadyNeutral }
}

/// The real ports' kind of directory (not Core's fake): the controller treats its displays as real.
@MainActor @Observable private final class RealDirectory: DisplayDirectory {
    let displays: [DisplayFacts]
    let generation = 0
    init(_ displays: [DisplayFacts]) { self.displays = displays }
    func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }
}

@MainActor @Suite struct CalibrationWindowTests {
    /// A display no screen of this Mac has (simulated), next to the fixture's.
    private static let simulated = DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000AA"),
                                                                id: 0xFFFF_FF00),
                                                name: "Simulated XDR", isBuiltIn: false, gammaCapacity: 1024,
                                                panelPeakNits: 1600, sdrMaxNits: 500, panelClass: .appleXDRExternal)

    private func services(_ boost: CalibratingBoost,
                          displays: any DisplayDirectory = FakeDisplayDirectory(displays: [Self.simulated])) -> OverbrightServices {
        OverbrightServices(settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(),
                           machine: DisplayFixture.ownerMachine, time: ManualTimeSource(), journal: RingBufferJournal(),
                           announcer: Announcer(post: { _ in }, now: { 0 }), ownEDRSurfaces: OwnEDRSurfaces(),
                           displays: displays, signals: FakeSystemSignals(),
                           boost: boost, fillLight: PreviewFillLightControl(), shortcuts: PreviewShortcutCenter(),
                           updates: PreviewUpdateChecking())
    }

    /// The number of this Mac's first screen, or a fixture's ID when the runner has none.
    private static var firstScreenNumber: UInt32 {
        NSScreen.screens.first.flatMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        } ?? 1
    }

    @Test func theWindowStartsASessionForItsDisplay() throws {
        _ = NSApplication.shared
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        let controller = CalibrationWindowController(services: services(boost))
        let window = controller.preparedWindow(for: Self.simulated.ref.key)
        let session = try #require(boost.sessions.first)
        #expect(boost.sessions.count == 1 && session.display == Self.simulated.ref.key)
        #expect(controller.model?.session === session && controller.model?.step == .checklist)
        #expect(window.contentView is NSHostingView<CalibrationView>)
        #expect(window.backgroundColor == .black && !window.isReleasedWhenClosed)
        #expect(window.title.contains(BidiIsolation.isolate("Simulated XDR")))         // isolated in the sentence
        // No screen of its own: an ordinary titled window, at the ordinary level.
        #expect(window.styleMask.contains(.titled) && window.level == .normal)
        window.close()
    }

    @Test func escEndsTheSessionAtOnceAndClosesTheWindow() throws {
        _ = NSApplication.shared
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        let controller = CalibrationWindowController(services: services(boost))
        let window = controller.preparedWindow(for: Self.simulated.ref.key)
        let session = try #require(boost.sessions.first)
        window.cancelOperation(nil)
        #expect(session.calls == ["cancel"])
        #expect(controller.window == nil && controller.model == nil)
    }

    @Test func closingTheWindowEndsARunningSession() throws {
        _ = NSApplication.shared
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        let controller = CalibrationWindowController(services: services(boost))
        let window = controller.preparedWindow(for: Self.simulated.ref.key)
        let session = try #require(boost.sessions.first)
        window.close()
        #expect(session.calls == ["cancel"] && controller.window == nil)
        // A second calibration gets a new session.
        _ = controller.preparedWindow(for: Self.simulated.ref.key)
        #expect(boost.sessions.count == 2)
        controller.window?.close()
    }

    /// A simulated display whose fixture ID is a real screen's number (fixtures 1 and 2 are a MacBook's built-in and a
    /// common second display) still gets the titled window: the real screens are never even looked up.
    @Test func aSimulatedDisplayNeverCoversARealScreen() throws {
        _ = NSApplication.shared
        var colliding = Self.simulated
        colliding.ref = DisplayRef(key: colliding.ref.key, id: Self.firstScreenNumber)
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        var lookups = 0
        let controller = CalibrationWindowController(services: services(boost, displays: FakeDisplayDirectory(displays: [colliding])),
                                                     screen: { _ in lookups += 1; return NSScreen.screens.first })
        #expect(controller.placement(for: colliding) == .simulated)
        let window = controller.preparedWindow(for: colliding.ref.key)
        #expect(lookups == 0)
        #expect(window.styleMask.contains(.titled) && window.level == .normal)
        #expect(window.contentRect(forFrameRect: window.frame).size == CalibrationWindowController.fallbackSize)
        #expect(boost.sessions.count == 1 && controller.model?.step == .checklist)          // the fake engine's session
        window.close()
    }

    /// A real display without a screen of its own begins no session: nothing may brighten it while the patches would
    /// show on another screen. The titled window says it can't be calibrated now.
    @Test func aRealDisplayWithoutAScreenBeginsNoSession() throws {
        _ = NSApplication.shared
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        let controller = CalibrationWindowController(services: services(boost, displays: RealDirectory([Self.simulated])),
                                                     screen: { _ in nil })
        #expect(controller.placement(for: Self.simulated) == .noScreen)
        let window = controller.preparedWindow(for: Self.simulated.ref.key)
        #expect(boost.sessions.isEmpty)
        #expect(controller.model?.step == .unavailable && controller.model?.session == nil)
        #expect(window.styleMask.contains(.titled) && window.level == .normal)
        window.close()
        // A display that is not online at all is treated the same.
        #expect(controller.placement(for: nil) == .noScreen)
    }

    /// A real display with a screen: the window covers that screen, borderless, above every app, in its colour space,
    /// and the session starts (the window is built, never ordered in).
    @Test func aRealDisplayWithAScreenIsCoveredBorderless() throws {
        _ = NSApplication.shared
        guard let screen = NSScreen.screens.first else { return }                // a runner without screens
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        let controller = CalibrationWindowController(services: services(boost, displays: RealDirectory([Self.simulated])),
                                                     screen: { _ in screen })
        let window = controller.preparedWindow(for: Self.simulated.ref.key)
        #expect(window.styleMask == [.borderless] && window.level == CalibrationWindowController.level)
        #expect(window.colorSpace == screen.colorSpace && window.frame == screen.frame)
        #expect(boost.sessions.count == 1 && controller.model?.step == .checklist)
        window.close()
        #expect(boost.sessions.first?.calls == ["cancel"])
    }

    /// The controller of the app reads "simulated" from the services: Core's fake directory is what `--qa-simulate` wires.
    @Test func simulationIsReadFromTheServices() {
        let boost = CalibratingBoost(fixture: .builtinXDRLidOpen)
        #expect(CalibrationWindowController(services: services(boost)).placement(for: Self.simulated) == .simulated)
        let real = CalibrationWindowController(services: services(boost, displays: RealDirectory([Self.simulated])))
        #expect(real.placement(for: Self.simulated) == .noScreen)              // no screen has the ID 0xFFFFFF00
    }

    /// On a display with a screen, the window covers it, above every app, in its colour space (read, never shown).
    @Test func aRealScreenIsCoveredInItsColorSpace() throws {
        let screen = try #require(NSScreen.screens.first)
        let number = try #require((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value)
        var facts = Self.simulated
        facts.ref = DisplayRef(key: facts.ref.key, id: number)
        #expect(CalibrationWindowController.screen(for: facts) == screen)
        #expect(CalibrationWindowController.screen(for: Self.simulated) == nil)
        #expect(CalibrationWindowController.level.rawValue == NSWindow.Level.screenSaver.rawValue - 1)
    }
}
