// OverbrightAppShellTests/CalibrationWindowTests.swift — the calibration window (ARCHITECTURE.md §7.6; DESIGN.md §9):
// it asks the engine for a session for its display, covers that display's screen borderless at `.screenSaver − 1` in
// the screen's colour space (an ordinary titled window for a display without a screen of its own), and Esc or closing
// it ends the session at once. A test never orders the window in: `preparedWindow(for:)` builds what `show` brings
// forward.
import AppKit
import Foundation
import Observation
import OverbrightCore
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

@MainActor @Suite struct CalibrationWindowTests {
    /// A display no screen of this Mac has (simulated), next to the fixture's.
    private static let simulated = DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000AA"),
                                                                id: 0xFFFF_FF00),
                                                name: "Simulated XDR", isBuiltIn: false, gammaCapacity: 1024,
                                                panelPeakNits: 1600, sdrMaxNits: 500, panelClass: .appleXDRExternal)

    private func services(_ boost: CalibratingBoost) -> OverbrightServices {
        OverbrightServices(settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(),
                           machine: DisplayFixture.ownerMachine, time: ManualTimeSource(), journal: RingBufferJournal(),
                           announcer: Announcer(post: { _ in }, now: { 0 }), ownEDRSurfaces: OwnEDRSurfaces(),
                           displays: FakeDisplayDirectory(displays: [Self.simulated]), signals: FakeSystemSignals(),
                           boost: boost, fillLight: PreviewFillLightControl(), shortcuts: PreviewShortcutCenter(),
                           updates: PreviewUpdateChecking())
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
        #expect(window.title.contains("Simulated XDR"))
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
