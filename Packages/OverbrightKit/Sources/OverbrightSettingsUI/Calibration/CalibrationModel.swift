// OverbrightSettingsUI/Calibration/CalibrationModel.swift — the steps of the calibration window (DESIGN.md §9;
// ARCHITECTURE.md §5.2) over a `CalibrationSession`, which owns every table write: the checklist (with the optional
// colorimeter value), step 1 (the display switches between Standard and ×1.3 light three times, at most once per 1.5 s,
// then "Did the screen get brighter…?"; No offers Compatibility mode, which repeats step 1 with a new session), step 2
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
    /// Where the window is.
    public enum Step: Hashable {
        /// No session: the display cannot be calibrated now.
        case unavailable
        /// "Before starting".
        case checklist
        /// Step 1: the comparison and its question.
        case comparison
        /// Step 1 answered No: Compatibility mode, or keep the color table.
        case notBrighter
        /// Step 2, before the sweep starts.
        case sweepIntro
        /// Step 2: the sweep runs (or waits at its pause).
        case sweep
        /// Step 3: the confirmation frame and its question.
        case confirmation
        /// The result.
        case results
    }

    /// What the results say.
    public enum Ending: Hashable {
        /// "Standard curve confirmed."
        case encoded
        /// "This display responds in linear light."
        case linear
        /// "The result wasn't clear, so Overbright keeps its safe default."
        case inconclusive
        /// The screen did not get brighter and the color table was kept.
        case keptColorTable
    }

    /// The display under test.
    public let display: DisplayKey
    /// Its name (the window's title and VoiceOver).
    public let displayName: String
    /// The step shown.
    public private(set) var step: Step
    /// The running session (nil once none could start).
    public private(set) var session: (any CalibrationSession)?
    /// Step 1's sequence is running.
    private(set) var isFlipping = false
    /// Changes shown in the current sequence (Brighter, Standard, … six in all).
    private(set) var flips = 0
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
    @ObservationIgnored private var flipTask: Task<Void, Never>?
    @ObservationIgnored private var stateToken: ObservationToken?
    /// The answer of step 1, once given.
    @ObservationIgnored private var brighter: Bool?

    /// Step 1 shows Brighter and Standard three times each.
    static let flipsPerSequence = 6
    /// At most one change per 1.5 s (DESIGN.md §3.4, §9).
    static let flipInterval: Duration = .milliseconds(1500)
    /// How often step 1 looks whether the session is ready (it shows a trigger and waits for extra range first).
    static let readinessPoll: Duration = .milliseconds(100)

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
    /// The live checklist can be passed.
    var canStart: Bool { step == .checklist && CalibrationChecklist.canStart(services.signals.snapshot) }
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
        step = yes ? .sweepIntro : .notBrighter
    }

    /// Compatibility mode on this display, then step 1 again with a session for it.
    func useCompatibilityMode() {
        guard step == .notBrighter else { return }
        store(session?.finish(brighter: false))
        DisplayPreferencesEditor(settings: services.settings).update(display, name: displayName) { $0.mechanism = .overlay }
        brighter = nil
        replaceSession()
        guard session != nil else { return }
        step = .comparison
        runComparison()
    }

    /// Keep the color table: the steps end.
    func keepColorTable() {
        guard step == .notBrighter else { return }
        store(session?.finish(brighter: false))
        DisplayPreferencesEditor(settings: services.settings).update(display, name: displayName) { $0.mechanism = .table }
        ending = .keptColorTable
        step = .results
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
        flips = 0
        isFlipping = true
        let time = services.time
        session.showComparison(boosted: false)                       // begins the session when it has not yet
        flipTask = Task { [weak self] in
            do {
                while self?.session?.state == .preparing { try await time.sleep(for: Self.readinessPoll) }
                for flip in 0..<Self.flipsPerSequence {
                    if flip > 0 { try await time.sleep(for: Self.flipInterval) }
                    guard let self, self.step == .comparison else { return }
                    self.session?.showComparison(boosted: flip.isMultiple(of: 2))
                    self.flips = flip + 1
                }
            } catch {
                return                                                   // cancelled
            }
            self?.isFlipping = false
        }
    }

    private func stopComparison() {
        flipTask?.cancel()
        flipTask = nil
        isFlipping = false
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
        case .aborted(let reason) where [.comparison, .notBrighter, .sweepIntro, .sweep, .confirmation].contains(step):
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
