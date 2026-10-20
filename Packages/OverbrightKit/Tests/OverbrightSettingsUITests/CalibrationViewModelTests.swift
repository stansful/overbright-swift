// OverbrightSettingsUITests/CalibrationViewModelTests.swift — the calibration window's steps (DESIGN.md §9;
// ARCHITECTURE.md §5.2) over a scripted session and manual time: the live checklist gates Start; step 1 waits for the
// session to be ready, then shows Brighter and Standard three times each, at most one change per 1.5 s; No goes
// straight to the results and keeps the color table; step 2 starts, keeps going past the pause
// and marks the merge with Space; step 3 appears only when the session asks for it; every result stores the session's
// record and ends with the "turn them back on" line; Esc stores nothing; a session that stops by itself ends the steps.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct CalibrationViewModelTests {
    private let display = DisplayFixture.Keys.builtIn

    /// A model over `sessions` (each Try Again takes the next one).
    private func model(_ services: OverbrightServices, sessions: [FakeCalibrationSession?]) -> (CalibrationModel, () -> Int) {
        var queue = sessions
        var begun = 0
        let model = CalibrationModel(display: display, name: "Built-in Display", services: services) {
            begun += 1
            return queue.isEmpty ? nil : queue.removeFirst()
        }
        return (model, { begun })
    }

    private func time(_ services: OverbrightServices) throws -> ManualTimeSource {
        try #require(services.time as? ManualTimeSource)
    }

    private func signals(_ services: OverbrightServices) throws -> FakeSystemSignals {
        try #require(services.signals as? FakeSystemSignals)
    }

    // MARK: Checklist

    @Test func withoutASessionTheWindowSaysSoAndCanTryAgain() {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession()
        let (model, begun) = model(services, sessions: [nil, session])
        #expect(model.step == .unavailable && !model.canStart)
        model.tryAgain()
        #expect(model.step == .checklist && model.session === session && begun() == 2)
    }

    @Test func startNeedsEveryLiveItemToPass() throws {
        let services = OverbrightServices.preview()
        let signals = try signals(services)
        let (model, _) = model(services, sessions: [FakeCalibrationSession()])
        #expect(model.canStart)
        signals.snapshot.power = PowerState(source: .battery, batteryPercent: 80, isLowPowerMode: false)
        #expect(!model.canStart)
        #expect(CalibrationChecklist.passes(.pluggedIn, signals.snapshot) == false)
        signals.snapshot.power = PowerState(source: .adapter, batteryPercent: 80, isLowPowerMode: false)
        signals.snapshot.thermal = .serious
        #expect(!model.canStart)
        signals.snapshot.thermal = .fair
        signals.snapshot.conflicts = [ConflictingApp(entryID: "S2-example", severity: .gammaWriter, bundleID: nil,
                                                     processID: 7, displayName: "Colors")]
        #expect(!model.canStart)
        signals.snapshot.conflicts = [ConflictingApp(entryID: "S4-example", severity: .benign, bundleID: nil,
                                                     processID: 7, displayName: "Benign")]
        #expect(model.canStart)                                                    // diagnostics-only apps don't count
        #expect(CalibrationChecklist.passes(.maximumBrightness, signals.snapshot) == nil)   // asked, never read
        #expect(CalibrationChecklist.Item.allCases.filter(\.isLive) == [.pluggedIn, .noOtherApps, .cool])
    }

    @Test func startHandsOverTheColorimeterValueOnlyWhenItsDisclosureIsOpen() {
        let services = OverbrightServices.preview()
        let first = FakeCalibrationSession(), second = FakeCalibrationSession()
        let (model, _) = model(services, sessions: [first])
        model.colorimeterNits = 512
        model.start()
        #expect(first.calls.first == "setMeasuredSDRWhite(nil)")
        let (other, _) = self.model(services, sessions: [second])
        other.showsColorimeter = true
        other.colorimeterNits = 512
        other.start()
        #expect(second.calls.first == "setMeasuredSDRWhite(512.0)")
    }

    /// The engine ignores a colorimeter value outside 20–4,000 nits; the field says so and Start waits, instead of
    /// the value being dropped without a word.
    @Test func anImplausibleColorimeterValueIsShownAndHoldsStart() {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession()
        let (model, _) = model(services, sessions: [session])
        model.colorimeterNits = 9000
        #expect(model.canStart && !model.colorimeterValueIsImplausible)              // the disclosure is closed
        model.showsColorimeter = true
        #expect(model.colorimeterValueIsImplausible && !model.canStart)
        model.start()
        #expect(model.step == .checklist && session.calls.isEmpty)
        for nits in [19.9, 4000.5, -1, .nan, .infinity] {
            model.colorimeterNits = nits
            #expect(model.colorimeterValueIsImplausible, "\(nits)")
        }
        for nits in [20, 160, 4000] as [Double] {
            model.colorimeterNits = nits
            #expect(!model.colorimeterValueIsImplausible && model.canStart, "\(nits)")
        }
        model.colorimeterNits = nil                                               // an empty field: no reading
        #expect(model.canStart)
        #expect(CalibrationCopy.sdrWhiteRange(locale: Locale(identifier: "en_US")) == "Use a value from 20 to 4,000.")
    }

    // MARK: Step 1

    @Test func theComparisonWaitsForTheSessionThenFlipsThreeTimesAtMostEveryHalfSecondAndASecond() async throws {
        let services = OverbrightServices.preview()
        let time = try time(services)
        let session = FakeCalibrationSession(state: .preparing)
        let (model, _) = model(services, sessions: [session])
        model.start()
        #expect(model.step == .comparison && model.isFlipping && model.isPreparing)
        await time.advance(by: .seconds(2))                                        // still preparing: nothing flips
        #expect(model.flips == 0 && session.calls == ["setMeasuredSDRWhite(nil)", "showComparison(false)"])
        session.state = .ready
        await time.advance(by: .milliseconds(100))
        #expect(model.flips == 1 && model.showsBrighter)
        await time.advance(by: .milliseconds(1400))                               // 1.5 s have not passed yet
        #expect(model.flips == 1)
        await time.advance(by: .milliseconds(100))
        #expect(model.flips == 2 && !model.showsBrighter)
        await time.advance(by: .seconds(6))
        #expect(model.flips == 6 && !model.isFlipping)
        let flips = session.calls.filter { $0.hasPrefix("showComparison") }.dropFirst()
        #expect(Array(flips) == ["showComparison(true)", "showComparison(false)", "showComparison(true)",
                                 "showComparison(false)", "showComparison(true)", "showComparison(false)"])
        model.showAgain()
        await time.advance(by: .milliseconds(100))
        #expect(model.isFlipping && model.flips == 1)
    }

    /// DESIGN.md §15: the flips are slow and announced. Each change is said as it is shown (feedback to the user's own
    /// check, never rate-limited), so the question after it can be answered without seeing the label.
    @Test func eachFlipIsAnnouncedAsItIsShown() async throws {
        var said: [String] = []
        let services = TestServices.make(boost: PreviewBoostControl(fixture: .builtinXDRLidOpen),
                                         announcer: Announcer(post: { said.append($0) }, now: { 0 }))
        let time = try time(services)
        let session = FakeCalibrationSession(state: .preparing)
        let (model, _) = model(services, sessions: [session])
        model.start()
        await time.advance(by: .seconds(1))
        #expect(said.isEmpty)                                                      // nothing shown, nothing said
        session.state = .ready
        await time.advance(by: .milliseconds(100))
        #expect(said == [CalibrationCopy.brighter] && model.showsBrighter)
        await time.advance(by: .milliseconds(1400))
        #expect(said.count == 1)                                                   // at most one per 1.5 s
        await time.advance(by: .seconds(10))
        let pair = [CalibrationCopy.brighter, CalibrationCopy.standard]
        #expect(said == pair + pair + pair && model.flips == ComparisonSequence.flipsPerSequence)
        model.answerBrighter(true)
        await time.advance(by: .seconds(10))
        #expect(said.count == 6)                                                   // the answer ends the sequence
    }

    @Test func yesLeadsToTheSweepAndReturnsTheDisplayToStandard() async throws {
        let services = OverbrightServices.preview()
        let time = try time(services)
        let session = FakeCalibrationSession(state: .ready)
        let (model, _) = model(services, sessions: [session])
        model.start()
        await time.advance(by: .milliseconds(100))
        #expect(model.showsBrighter)
        model.answerBrighter(true)
        #expect(model.step == .sweepIntro && !model.isFlipping && !model.showsBrighter)
        await time.advance(by: .seconds(10))                                       // the sequence stopped for good
        #expect(model.flips == 1)
    }

    /// No goes straight to the results: the answer is stored, the session ends, and the method stays as it was.
    @Test func noStoresTheAnswerAndGoesStraightToTheResults() async throws {
        let services = OverbrightServices.preview()
        let time = try time(services)
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.notBrighter)
        let (model, begun) = model(services, sessions: [session])
        model.start()
        await time.advance(by: .milliseconds(100))
        model.answerBrighter(false)
        #expect(model.step == .results && model.ending == .keptColorTable && !model.isFlipping)
        let preferences = DisplayPreferencesEditor(settings: services.settings).preferences(of: display)
        #expect(session.calls.last == "finish(false)")
        #expect(preferences.calibration?.outcome == .notBrighter)
        #expect(begun() == 1)
        #expect(CalibrationCopy.result(.keptColorTable) != CalibrationCopy.result(.inconclusive))
    }

    // MARK: Step 2 and step 3

    @Test func theSweepKeepsGoingPastThePauseAndAMergeNearTheEncodedPredictionEnds() async throws {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.encoded)
        let (model, _) = model(services, sessions: [session])
        model.start()
        model.answerBrighter(true)
        model.startSweep()
        #expect(model.step == .sweep && session.state == .sweeping && model.showsPatches)
        session.isSweepPausedAtLimit = true
        model.markMerged()                                                         // Space waits while paused
        #expect(!session.calls.contains("markMerged"))
        model.keepGoing()
        #expect(session.calls.contains("continueSweep") && !model.isSweepPaused)
        model.markMerged()
        #expect(session.calls.last == "markMerged")
        session.state = .swept(mergeFactor: 1.62, needsConfirmation: false)       // the session ends the sweep
        #expect(await eventually { model.step == .results })
        #expect(model.ending == .encoded && session.calls.last == "finish(true)")
        #expect(DisplayPreferencesEditor(settings: services.settings).preferences(of: display).calibration?.outcome == .encoded)
        #expect(!model.showsPatches)
    }

    @Test func aMergeNearTheLinearPredictionNeedsTheConfirmation() async {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.linear)
        let (model, _) = model(services, sessions: [session])
        model.start()
        model.answerBrighter(true)
        model.startSweep()
        session.state = .swept(mergeFactor: 2.99, needsConfirmation: true)
        #expect(await eventually { model.step == .confirmation })
        model.answerConfirmation(different: true)                                  // not before the frame was shown
        #expect(!session.calls.contains { $0.hasPrefix("answerLinearConfirmation") } && model.step == .confirmation)
        model.showConfirmation()
        #expect(model.isConfirming && session.calls.last == "showLinearConfirmation")
        session.state = .swept(mergeFactor: 2.99, needsConfirmation: true)         // the 2-s frame is over
        model.answerConfirmation(different: true)
        #expect(session.calls.suffix(2) == ["answerLinearConfirmation(true)", "finish(true)"])
        #expect(model.step == .results && model.ending == .linear)
    }

    @Test func stoppingAtThePauseIsNotClear() async {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.inconclusive)
        let (model, _) = model(services, sessions: [session])
        model.start()
        model.answerBrighter(true)
        model.startSweep()
        session.isSweepPausedAtLimit = true
        model.stopSweep()
        #expect(await eventually { model.step == .results })
        #expect(model.ending == .inconclusive && model.stopReason == nil)          // the user's own stop needs no reason
        #expect(session.calls.contains("cancel"))
    }

    @Test func aSessionThatStopsByItselfEndsTheStepsWithTheReason() async {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.inconclusive)
        let (model, _) = model(services, sessions: [session])
        model.start()
        model.answerBrighter(true)
        model.startSweep()
        session.state = .aborted(.headroomDropped)
        #expect(await eventually { model.step == .results })
        #expect(model.stopReason == .headroomDropped && model.ending == .inconclusive)
        #expect(CalibrationCopy.stopped(.headroomDropped) != nil && CalibrationCopy.stopped(.cancelled) == nil)
        #expect(session.calls.last == "finish(true)")
    }

    // MARK: Leaving

    @Test func escEndsTheSessionAtOnceAndStoresNothing() async throws {
        let services = OverbrightServices.preview()
        let session = FakeCalibrationSession(state: .ready)
        session.record = FakeCalibrationSession.record(.encoded)
        let (model, _) = model(services, sessions: [session])
        var closed = 0
        model.onClose = { closed += 1 }
        model.start()
        model.answerBrighter(true)
        model.startSweep()
        model.cancel()
        #expect(session.calls.last == "cancel" && closed == 1)
        try await Task.sleep(for: .milliseconds(50))                               // the end it caused is not a result
        #expect(model.step == .sweep && !session.calls.contains { $0.hasPrefix("finish") })
        #expect(DisplayPreferencesEditor(settings: services.settings).preferences(of: display).calibration == nil)
    }

    @Test func everyResultIsFollowedByTheTurnThemBackOnLine() {
        for ending in [CalibrationModel.Ending.encoded, .linear, .inconclusive, .keptColorTable] {
            #expect(!CalibrationCopy.result(ending).isEmpty)
        }
        let endings = [CalibrationModel.Ending.encoded, .linear, .inconclusive, .keptColorTable].map(CalibrationCopy.result)
        #expect(Set(endings).count == 4 && !endings.contains(CalibrationCopy.turnBackOn))
    }

    @Test func tryAgainAfterAnUnclearResultStartsOver() async {
        let services = OverbrightServices.preview()
        let first = FakeCalibrationSession(state: .ready), second = FakeCalibrationSession(state: .ready)
        first.record = FakeCalibrationSession.record(.inconclusive)
        let (model, begun) = model(services, sessions: [first, second])
        model.start()
        model.answerBrighter(true)
        model.tryAgain()                                                           // not in the middle of the steps
        #expect(model.session === first && begun() == 1)
        model.startSweep()
        first.state = .swept(mergeFactor: nil, needsConfirmation: false)          // Space never pressed
        #expect(await eventually { model.step == .results })
        #expect(model.ending == .inconclusive)
        model.tryAgain()
        #expect(model.session === second && model.step == .checklist && model.ending == nil && begun() == 2)
    }
}
