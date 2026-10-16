// OverbrightSettingsUITests/SelfTestSheetTests.swift — the self-test sheet (DESIGN.md §10; ARCHITECTURE.md §8.4): the
// displays offered and chosen, the options handed to the engine, the progress per display read from the journal,
// Stop (the awaiting task is cancelled and the partial report shown), the results table and summaries, Save Log…
// (through `AppControl`), Copy (the JSON), and the archive of the last ten logs.
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct SelfTestSheetTests {
    private let builtIn = DisplayFixture.Keys.builtIn
    private let held = TestServices.result(.taggedLayer, .black, .held, movement: 0.4, stable: 1.6)
    private let dropped = TestServices.result(.taggedLayer, .bright, .engagedButDropped, movement: 0.5)

    private func setup(_ fixture: DisplayFixture = .builtinXDRLidOpen)
        -> (OverbrightServices, TestBoostControl, SelfTestModel, () -> [String]) {
        let boost = TestBoostControl(fixture: fixture, report: TestServices.report([held]),
                                     stoppedReport: TestServices.report([dropped]))
        let services = TestServices.make(fixture: fixture, boost: boost)
        var copied: [String] = []
        let model = SelfTestModel(services: services, copy: { copied.append($0) }, archiveFolder: .some(nil))
        return (services, boost, model, { copied })
    }

    // MARK: Before

    @Test func everyDisplayWithItsOwnPictureIsOfferedAndChosen() {
        let (_, _, model, _) = setup(.sidecar)
        #expect(model.displays.map(\.key) == [builtIn])                           // not the Sidecar display
        let (_, _, mirrored, _) = setup(.hardwareMirror)
        #expect(mirrored.displays.map(\.key) == [builtIn])                         // not the mirror member
        let (_, _, two, _) = setup(.russianNames)
        #expect(two.chosen == Set(two.displays.map(\.key)) && two.canRun)
        two.chosen = []
        #expect(!two.canRun)
    }

    @Test func runHandsTheOptionsToTheEngineAndShowsTheResults() async {
        let (services, boost, model, _) = setup(.russianNames)
        model.chosen = [DisplayFixture.Keys.mpg322ux]
        model.everyMethod = true
        boost.runsUntilEnded = false
        model.start()
        #expect(await eventually { if case .results = model.phase { true } else { false } })
        let options = boost.selfTestOptions.first
        #expect(options?.everyStrategy == true && options?.displays == [DisplayFixture.Keys.mpg322ux])
        #expect(options?.secondsPerStrategy == SelfTestOptions().secondsPerStrategy)
        #expect(model.phase == .results(boost.report))
        model.save()
        #expect((services.app as? PreviewAppControl)?.calls == ["saveSelfTestLog"])
    }

    @Test func stopCancelsTheRunAndShowsWhatWasMeasured() async {
        let (_, boost, model, _) = setup()
        model.start()
        #expect(model.phase == .running && !model.canRun)
        #expect(await eventually { boost.selfTestOptions.count == 1 })
        model.stop()
        #expect(await eventually { model.phase == .results(boost.stoppedReport) })
    }

    @Test func copyPutsTheReportAsJSONOnTheClipboard() async throws {
        let (_, boost, model, copied) = setup()
        boost.runsUntilEnded = false
        model.copy()                                                               // nothing before the results
        #expect(copied().isEmpty)
        model.start()
        #expect(await eventually { model.phase == .results(boost.report) })
        model.copy()
        let text = try #require(copied().first)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(SelfTestReport.self, from: Data(text.utf8)) == boost.report)
        #expect(!text.contains("Built-in"))                                        // no names in a log
    }

    // MARK: Progress

    @Test func progressFollowsTheJournalDisplayAfterDisplay() {
        let machine = DisplayFixture.ownerMachine
        let plan = SelfTestPlan.rungs(everyMethod: false, machine: machine)
        let second = DisplayFixture.Keys.mpg322ux
        func event(_ code: String, _ at: Double, _ display: DisplayKey?, rung: Int? = nil) -> JournalEvent {
            JournalEvent(seconds: at, category: LogCategory.selfTest.rawValue, display: display?.rawValue, code: code,
                         values: rung.map { ["rung": Double($0)] } ?? [:])
        }
        var events = [event("selftest.started", 100, nil)]
        var progress = SelfTestProgress.make(displays: [builtIn, second], plan: plan, everyMethod: false, secondsPerRung: 31,
                                             events: events, since: 100, now: 112)
        #expect(progress[0].rung == plan[0] && progress[0].secondsInRung == 12 && !progress[0].isFinished)
        #expect(progress[0].fraction > 0 && progress[0].fraction < 1.0 / Double(plan.count))
        #expect(progress[1].fraction == 0 && progress[1].rung == nil)
        events.append(event("selftest.noEngage", 131, builtIn, rung: 0))
        progress = SelfTestProgress.make(displays: [builtIn, second], plan: plan, everyMethod: false, secondsPerRung: 31,
                                         events: events, since: 100, now: 135)
        #expect(progress[0].rung == plan[1] && progress[0].secondsInRung == 4)
        events.append(event("selftest.held", 162, builtIn, rung: 1))              // held: the display is done
        events.append(JournalEvent(seconds: 163, category: LogCategory.engine.rawValue, display: builtIn.rawValue,
                                   code: "gate.ready"))                            // other categories are ignored
        progress = SelfTestProgress.make(displays: [builtIn, second], plan: plan, everyMethod: false, secondsPerRung: 31,
                                         events: events, since: 100, now: 170)
        #expect(progress[0].isFinished && progress[0].fraction == 1)
        #expect(progress[1].rung == plan[0] && progress[1].secondsInRung == 8)
        let line = SelfTestText.progress(display: "Built-in Display", rung: plan[0], seconds: 12)
        #expect(line.hasPrefix("Built-in Display") && line.contains(TriggerStrategy.taggedLayer.localizedName(pixel: .black)))
        #expect(line.contains("12"))
    }

    /// With every method, a rung that held does not end the display; an old run's events are ignored.
    @Test func everyMethodRunsEveryRung() {
        let plan = SelfTestPlan.rungs(everyMethod: true, machine: DisplayFixture.ownerMachine)
        let events = [JournalEvent(seconds: 50, category: LogCategory.selfTest.rawValue, display: builtIn.rawValue,
                                   code: "selftest.held", values: ["rung": 0]),
                      JournalEvent(seconds: 110, category: LogCategory.selfTest.rawValue, display: builtIn.rawValue,
                                   code: "selftest.held", values: ["rung": 0])]
        let progress = SelfTestProgress.make(displays: [builtIn], plan: plan, everyMethod: true, secondsPerRung: 31,
                                             events: events, since: 100, now: 115)
        #expect(!progress[0].isFinished && progress[0].rung == plan[1])
    }

    @Test func thePlanFollowsTheLadderAndTheMacOS() {
        var old = DisplayFixture.ownerMachine
        old.osMajor = 15
        let modern = SelfTestPlan.rungs(everyMethod: false, machine: DisplayFixture.ownerMachine)
        #expect(modern.map(\.strategy) == [.taggedLayer, .taggedLayer, .metalOneShot, .metalOneShot, .metalKeepAlive,
                                           .hlgStill, .hlgStill])
        #expect(modern.allSatisfy { $0.isAvailable })
        #expect(SelfTestPlan.rungs(everyMethod: false, machine: old).first?.strategy == .metalOneShot)
        let every = SelfTestPlan.rungs(everyMethod: true, machine: old)
        #expect(every.count == 8 && every.filter { !$0.isAvailable }.map(\.strategy) == [.taggedLayer, .taggedLayer])
        #expect(every.contains { $0.strategy == .hlgSampleBuffer })
    }

    // MARK: Results

    /// "Built-in Display: Tagged layer works. It will be used from now on." only after a clean pass.
    @Test func theSummaryNamesTheMethodOnlyAfterACleanPass() {
        let works = SelfTestText.summary(display: "Built-in Display", results: [dropped, held])
        let none = SelfTestText.summary(display: "Built-in Display", results: [dropped])
        #expect(works.contains(TriggerStrategy.taggedLayer.localizedName()) && works.contains("Built-in Display"))
        #expect(!none.contains(TriggerStrategy.taggedLayer.localizedName()))
        let invalid = TestServices.result(.metalOneShot, .black, .invalidBaseline)
        #expect(SelfTestText.summary(display: "Built-in Display", results: [invalid, held]) == none)   // not clean
        #expect(SelfTestPlan.cleanWinner(in: [dropped]) == nil)
        #expect(SelfTestPlan.cleanWinner(in: [dropped, held]) == held)
    }

    @Test func theTableShowsMethodResultAndTimes() {
        let english = Locale(identifier: "en_US")
        let cells = SelfTestResultsTable.cells(held)
        #expect(cells == [TriggerStrategy.taggedLayer.localizedName(pixel: .black),
                          SelfTestStrategyResult.Verdict.held.localizedName(),
                          SelfTestText.time(0.4), SelfTestText.time(1.6)])
        #expect(SelfTestText.time(nil, locale: english) == "—")
        #expect(SelfTestText.time(1.6, locale: english).hasPrefix("1.6"))
        #expect(SelfTestResultsTable.cells(dropped)[3] == "—")
    }

    @Test func resultsKeepTheSheetsDisplayOrder() {
        let (_, _, model, _) = setup(.russianNames)
        let report = SelfTestReport(startedAt: .now, machine: DisplayFixture.ownerMachine, appVersion: "0.1.0",
                                    displays: [DisplayFixture.Keys.mpg322ux.rawValue: [dropped], builtIn.rawValue: [held]],
                                    journal: [])
        #expect(model.orderedResults(report).map(\.key) == [builtIn.rawValue, DisplayFixture.Keys.mpg322ux.rawValue])
        #expect(model.name(of: "0B21E7F1-0000-4000-8000-0000000000FF") == SelfTestText.unknownDisplay)
    }

    // MARK: The log

    @Test func theArchiveKeepsTheLastTenLogs() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        for minute in 0..<12 {
            var report = TestServices.report([held])
            report.startedAt = Date(timeIntervalSinceReferenceDate: 800_000_000 + Double(minute) * 60)
            try await SelfTestLog.archive(report, in: folder)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names.count == SelfTestLog.kept)
        #expect(names.first == SelfTestLog.fileName(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_120)))
        #expect(names.allSatisfy { !$0.contains(":") && $0.hasSuffix(".json") })
    }
}
