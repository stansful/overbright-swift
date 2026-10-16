// OverbrightSettingsUITests/PaneSnapshotTests.swift — every pane, the calibration window's steps and the self-test
// sheet rendered in Light, Dark and Increase Contrast (ARCHITECTURE.md §9.1 UI row, §10.13 "snapshots of every pane"):
// in-process, never ordered in, each checked for ink; PNGs land in `$OVERBRIGHT_SNAPSHOT_DIR/SettingsUI/` when set.
// The panes show the built-in display and the OLED external as a running engine classifies them, with the schedule on.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct PaneSnapshotTests {
    /// The detail column at the window's default size.
    static let paneSize = CGSize(width: SettingsMetrics.windowSize.width - SettingsMetrics.sidebarWidth.ideal, height: 1300)

    /// Every pane with the environment the Settings window gives it.
    static func panes() -> [(String, AnyView)] {
        let services = PaneValues.richServices()
        return SettingsPaneID.allCases.map { pane in
            let view = SettingsPaneCatalog.view(for: pane, services: services)
                .environment(SettingsNavigator(target: pane.rawValue))
                .environment(ResetAllController(services: services))
            return ("pane-\(pane.rawValue)", AnyView(view))
        }
    }

    /// The calibration window's steps over a scripted session.
    static func calibrationSteps() -> [(String, AnyView)] {
        func model(_ prepare: (CalibrationModel, FakeCalibrationSession) -> Void) -> CalibrationModel {
            let session = FakeCalibrationSession(state: .ready)
            let model = CalibrationModel(display: DisplayFixture.Keys.builtIn, name: "Built-in Retina Display",
                                         services: .preview()) { session }
            prepare(model, session)
            return model
        }
        let checklist = model { _, _ in }
        let comparison = model { model, session in model.start(); session.showComparison(boosted: true) }
        let paused = model { model, session in
            model.start(); model.answerBrighter(true); model.startSweep(); session.isSweepPausedAtLimit = true
        }
        let results = model { model, session in
            session.record = FakeCalibrationSession.record(.encoded)
            model.start(); model.answerBrighter(false); model.keepColorTable()
        }
        return [("calibration-checklist", checklist), ("calibration-comparison", comparison),
                ("calibration-sweep-paused", paused), ("calibration-results", results)]
            .map { ($0.0, AnyView(CalibrationView(model: $0.1))) }
    }

    @Test(arguments: ChromeAppearance.allCases)
    func everyPaneRenders(_ appearance: ChromeAppearance) throws {
        for (name, view) in Self.panes() {
            let rep = try ChromeSnapshot.render(view, appearance, size: Self.paneSize)
            #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }

    @Test(arguments: ChromeAppearance.allCases)
    func theCalibrationStepsRenderOnBlack(_ appearance: ChromeAppearance) throws {
        for (name, view) in Self.calibrationSteps() {
            let rep = try ChromeSnapshot.render(view, appearance, size: CGSize(width: 900, height: 560))
            #expect(ChromeSnapshot.backgroundBrightness(rep) < 0.05, "\(name): the surround is not black")
            #expect(ChromeSnapshot.inkFraction(rep) > 0.02, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }

    @Test(arguments: ChromeAppearance.allCases)
    func theSelfTestSheetRenders(_ appearance: ChromeAppearance) async throws {
        let before = SelfTestSheet(model: SelfTestModel(services: TestServices.classified(.russianNames),
                                                        archiveFolder: .some(nil))) {}
        let boost = TestBoostControl(report: TestServices.report([
            TestServices.result(.taggedLayer, .black, .noEngage), TestServices.result(.taggedLayer, .bright, .held, movement: 0.4, stable: 1.6),
        ]), stoppedReport: TestServices.report([]))
        boost.runsUntilEnded = false
        let finished = SelfTestModel(services: TestServices.make(boost: boost), archiveFolder: .some(nil))
        finished.start()
        _ = await eventually { if case .results = finished.phase { true } else { false } }
        for (name, view) in [("selftest-before", AnyView(before)), ("selftest-results", AnyView(SelfTestSheet(model: finished) {}))] {
            let rep = try ChromeSnapshot.render(view, appearance, size: SelfTestSheet.size)
            #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }
}
