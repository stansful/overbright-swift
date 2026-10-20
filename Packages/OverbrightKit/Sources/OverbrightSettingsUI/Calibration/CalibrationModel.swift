// OverbrightSettingsUI/Calibration/CalibrationModel.swift — the steps of the calibration window (DESIGN.md §9;
// ARCHITECTURE.md §5.2) over a `CalibrationSession`, which owns every table write: the checklist (with the optional
// colorimeter value, checked against the range the engine accepts), step 1 (the display switches between Standard and
// ×1.3 light three times, at most once per 1.5 s, each change announced to VoiceOver; `ComparisonSequence` paces them;
// then "Did the screen get brighter…?"; No goes straight to the results, and the color table stays), step 2
// (the sweep on the black surround with its pause, ended by Space), step 3 (only after a merge near the linear
// prediction: the 2-s confirmation frame and its question), and the results with the "turn them back on" line. The
// record `finish(brighter:)` returns is stored with the display's preferences. Esc ends the session at once and stores
// nothing; a session that ends on its own (a lock, a headroom drop, the minute's limit) ends the steps with what it
// measured. Starting a session already returned every display to Standard and holds Overbright off until it ends.
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.engine)

/// The calibration window's state.
@Observable public final class CalibrationModel {
    /// The display under test.
    public let display: DisplayKey
    /// Its name (the window's title and VoiceOver).
    public let displayName: String
    /// The step shown.
    public private(set) var step: Step
    /// The running session (nil once none could start).
    public private(set) var session: (any CalibrationSession)?
    /// Step 1's sequence.
    let comparison = ComparisonSequence()
    /// The result, once the steps ended.
    private(set) var ending: Ending?
    /// Why the session ended early, when it did.
    private(set) var stopReason: CalibrationAbortReason?
    /// The colorimeter disclosure is open.
    var showsColorimeter = false
    /// SDR white measured at Standard with a colorimeter, in nits.
    var colorimeterNits: Double?
    /// Closes the window (Esc, Done).
    @ObservationIgnored public var onClose: (@MainActor () -> Void)?

    @ObservationIgnored private let services: OverbrightServices
    @ObservationIgnored private let begin: @MainActor () -> (any CalibrationSession)?
    @ObservationIgnored private var stateToken: ObservationToken?
    /// The answer of step 1, once given.
    @ObservationIgnored private var brighter: Bool?

    /// SDR white a colorimeter can plausibly read at Standard, in nits. The engine ignores any other value (Boost's
    /// `CalibrationMath.plausibleSDRWhite`), so the field says so and Start waits (WP14).
    static let plausibleSDRWhite: ClosedRange<Double> = 20...4000

    /// A model for `display`, starting with the session `begin` returns (nil: the display cannot be calibrated now).
    public init(display: DisplayKey, name: String, services: OverbrightServices,
         begin: @escaping @MainActor () -> (any CalibrationSession)?) {
        self.display = display; displayName = name; self.services = services; self.begin = begin
        let session = begin()
        self.session = session
        step = session == nil ? .unavailable : .checklist
        observeSession()
    }

    /// A model for `display` that asks the engine for its session (`BoostControl.beginCalibration`).
    public convenience init(display: DisplayKey, name: String, services: OverbrightServices) {
        self.init(display: display, name: name, services: services) { [boost = services.boost] in
            boost.beginCalibration(of: display)
        }
    }

    // MARK: Reading

    /// What the checklist reads live (the power source, other apps, the thermal state).
    var systemSnapshot: SystemSnapshot { services.signals.snapshot }
    /// The live checklist can be passed, and an open colorimeter field holds nothing the engine would ignore.
    var canStart: Bool {
        step == .checklist && !colorimeterValueIsImplausible && CalibrationChecklist.canStart(services.signals.snapshot)
    }
    /// The open colorimeter field holds a value outside `plausibleSDRWhite` (an empty field is fine: no reading).
    var colorimeterValueIsImplausible: Bool {
        guard showsColorimeter, let nits = colorimeterNits else { return false }
        return !(nits.isFinite && Self.plausibleSDRWhite.contains(nits))
    }
    /// Step 1's sequence is running.
    var isFlipping: Bool { comparison.isRunning }
    /// Changes shown in step 1's sequence.
    var flips: Int { comparison.flips }
    /// The session prepares the display (a trigger, waiting for extra range).
    var isPreparing: Bool { session?.state == .preparing }
    /// The display shows the boosted comparison now.
    var showsBrighter: Bool { (session?.currentFactor ?? 1) > 1 }
    /// The sweep waits at its pause for Keep Going.
    var isSweepPaused: Bool { session?.isSweepPausedAtLimit ?? false }
    /// Step 3's frame is on screen.
    var isConfirming: Bool { session?.state == .confirming }
    /// Step 3's frame was shown at least once (the answers wait for it).
    private(set) var confirmationShown = false
    /// The patches are on screen (steps 1–3).
    var showsPatches: Bool { [.comparison, .sweepIntro, .sweep, .confirmation].contains(step) }

    // MARK: Checklist

    /// Start: hands the colorimeter value over and begins step 1.
    func start() {
        guard canStart, let session else { return }
        session.setMeasuredSDRWhite(nits: showsColorimeter ? colorimeterNits : nil)
        step = .comparison
        runComparison()
    }

    // MARK: Step 1

    /// Show Again: the sequence once more.
    func showAgain() {
        guard step == .comparison, !isFlipping else { return }
        runComparison()
    }

    /// The answer to "Did the screen get brighter when the label said Brighter?".
    func answerBrighter(_ yes: Bool) {
        guard step == .comparison else { return }
        stopComparison()
        brighter = yes
        if yes {
            step = .sweepIntro
        } else {
            // No: the steps end, and the record says the screen did not get brighter.
            store(session?.finish(brighter: false))
            ending = .keptColorTable
            step = .results
        }
    }

    // MARK: Step 2

    /// Starts the sweep.
    func startSweep() {
        guard step == .sweepIntro, let session else { return }
        step = .sweep
        session.startSweep()
    }

    /// Keep Going: past the pause.
    func keepGoing() {
        guard step == .sweep, isSweepPaused else { return }
        session?.continueSweep()
    }

    /// Stop at the pause: the sweep ends early, so the result is not clear.
    func stopSweep() {
        guard step == .sweep else { return }
        session?.cancel()
    }

    /// Space: the two squares on the right merged.
    func markMerged() {
        guard step == .sweep, !isSweepPaused else { return }
        session?.markMerged()
    }

    // MARK: Step 3

    /// Show (and Show Again): the confirmation frame for two seconds.
    func showConfirmation() {
        guard step == .confirmation, !isConfirming else { return }
        confirmationShown = true
        session?.showLinearConfirmation()
    }

    /// The answer to "Can you still tell the two squares on the right apart?".
    func answerConfirmation(different: Bool) {
        guard step == .confirmation, confirmationShown else { return }
        session?.answerLinearConfirmation(distinguishable: different)
        complete()
    }

    // MARK: Results and closing

    /// Try Again: a new session and the checklist.
    func tryAgain() {
        guard step == .results || step == .unavailable else { return }
        brighter = nil
        ending = nil
        stopReason = nil
        confirmationShown = false
        replaceSession()
        if session != nil { step = .checklist }
    }

    /// Done: closes the window.
    func done() { onClose?() }

    /// Esc (and closing the window): the display returns to Standard at once; nothing is stored.
    public func cancel() {
        stateToken?.cancel()                                         // the end it causes is not a result
        stateToken = nil
        stopComparison()
        if let session, !Self.hasEnded(session.state) { session.cancel() }
        onClose?()
    }

    // MARK: Private

    private func runComparison() {
        guard let session else { return }
        stopComparison()
        session.showComparison(boosted: false)                       // begins the session when it has not yet
        comparison.start(time: services.time, isPreparing: { [weak self] in self?.session?.state == .preparing }) {
            [weak self] brighter in
            guard let self, self.step == .comparison, let session = self.session else { return false }
            session.showComparison(boosted: brighter)
            // Said as well as shown (DESIGN.md §15: the flips are slow and announced): the user's own check.
            self.services.announcer.announce(brighter ? CalibrationCopy.brighter : CalibrationCopy.standard, kind: .feedback)
            return true
        }
    }

    private func stopComparison() {
        comparison.stop()
        if step == .comparison, showsBrighter { session?.showComparison(boosted: false) }
    }

    /// Ends the steps with what the session measured.
    private func complete() {
        let record = session?.finish(brighter: brighter)
        store(record)
        ending = switch record?.outcome {
        case .encoded?: .encoded
        case .linear?: .linear
        default: .inconclusive
        }
        step = .results
    }

    private func store(_ record: CalibrationRecord?) {
        guard let record else { return }
        DisplayPreferencesEditor(settings: services.settings).update(display, name: displayName) { $0.calibration = record }
        log.info("calibration stored: \(record.outcome.rawValue, privacy: .public)")
    }

    private func replaceSession() {
        if let session, !Self.hasEnded(session.state) { session.cancel() }
        session = begin()
        if session == nil { step = .unavailable }
        observeSession()
    }

    private func observeSession() {
        stateToken = observe({ [weak self] in self?.session?.state }) { [weak self] state in
            guard let state else { return }
            self?.sessionChanged(state)
        }
    }

    /// The session moved on by itself: the sweep ended, or the session stopped early.
    private func sessionChanged(_ state: CalibrationState) {
        switch state {
        case .swept(_, let needsConfirmation) where step == .sweep:
            if needsConfirmation { step = .confirmation } else { complete() }
        case .aborted(let reason) where [.comparison, .sweepIntro, .sweep, .confirmation].contains(step):
            stopComparison()
            stopReason = reason == .cancelled ? nil : reason
            log.info("calibration ended early: \(reason.rawValue, privacy: .public)")
            complete()
        case .aborted(let reason) where step == .checklist:
            stopReason = reason
            step = .results
            ending = .inconclusive
        default:
            break
        }
    }

    private static func hasEnded(_ state: CalibrationState) -> Bool {
        switch state {
        case .aborted, .finished: true
        default: false
        }
    }
}
