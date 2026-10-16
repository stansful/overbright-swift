// OverbrightSettingsUITests/PaneSnapshotTests.swift — every pane, the calibration window's steps and the self-test
// sheet rendered in Light, Dark and Increase Contrast (ARCHITECTURE.md §9.1 UI row, §10.13 "snapshots of every pane"):
// in-process, never ordered in, each checked for ink; PNGs land in `$OVERBRIGHT_SNAPSHOT_DIR/SettingsUI/` when set.
// The panes show the built-in display and the OLED external as a running engine classifies them, with the schedule on,
// and the apps they list are looked up first, so the Automations snapshot shows names and icons, not pending rows.
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
    static func panes(_ services: OverbrightServices = PaneValues.richServices()) -> [(String, AnyView)] {
        SettingsPaneID.allCases.map { pane in
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
        let colorimeter = model { model, _ in model.showsColorimeter = true; model.colorimeterNits = 9000 }
        let results = model { model, session in
            session.record = FakeCalibrationSession.record(.encoded)
            model.start(); model.answerBrighter(false); model.keepColorTable()
        }
        return [("calibration-checklist", checklist), ("calibration-colorimeter-range", colorimeter),
                ("calibration-comparison", comparison),
                ("calibration-sweep-paused", paused), ("calibration-results", results)]
            .map { ($0.0, AnyView(CalibrationView(model: $0.1))) }
    }

    /// Looks up every app the panes name (the paused apps, the other apps) and waits for the answers: the rows of a
    /// pending lookup are blank (no name, no icon), which is not what a person sees a moment later.
    static func resolveApps(_ services: OverbrightServices) async -> [String] {
        let resolver = AppIdentityResolver.shared
        let ids = services.settings[AutomationSettings.pausedApps].map(\.bundleID)
            + services.signals.snapshot.conflicts.compactMap(\.bundleID)
        for id in ids { _ = resolver.identity(of: id) }
        _ = await eventually { !resolver.isLookingUp }
        return ids.filter { resolver.identity(of: $0).isPending }
    }

    @Test(arguments: ChromeAppearance.allCases)
    func everyPaneRenders(_ appearance: ChromeAppearance) async throws {
        let services = PaneValues.richServices()
        let pending = await Self.resolveApps(services)
        #expect(pending.isEmpty, "apps still looked up when the panes render: \(pending)")
        for (name, view) in Self.panes(services) {
            let rep = try ChromeSnapshot.render(view, appearance, size: Self.paneSize)
            #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }

    /// Fill Light's three sliders share one track (DESIGN.md §7.2, §7.7): the same width at the same place, with Cool
    /// and Warm under the warmth track rather than beside it (where they made it about 60 pt shorter). Read from the
    /// rendered pane through the tracks' layout bounds.
    @Test func fillLightSlidersShareOneTrack() throws {
        final class Frames { var byTitle: [String: CGRect] = [:] }
        let frames = Frames()
        let services = OverbrightServices.preview()
        let pane = SettingsPaneCatalog.view(for: .fillLight, services: services)
            .environment(SettingsNavigator(target: "fillLight"))
            .environment(ResetAllController(services: services))
            .overlayPreferenceValue(SliderTrackBounds.self) { anchors in
                GeometryReader { proxy in
                    let _ = frames.byTitle = anchors.mapValues { proxy[$0] }
                    Color.clear
                }
            }
        _ = try ChromeSnapshot.render(pane, .light, size: Self.paneSize)
        let tracks = [FillLightRows.width, FillLightRows.warmth, FillLightRows.brightness].compactMap { frames.byTitle[$0.title] }
        try #require(tracks.count == 3, "tracks found: \(frames.byTitle.keys.sorted())")
        #expect(Set(tracks.map { $0.width.rounded() }).count == 1, "track widths \(tracks.map(\.width))")
        #expect(Set(tracks.map { $0.minX.rounded() }).count == 1, "track starts \(tracks.map(\.minX))")
        #expect(tracks.allSatisfy { $0.width >= SettingsMetrics.sliderWidth.min })
    }

    /// The sliders settle on whole steps in the binding (they draw no tick marks); the default comes back exactly.
    @Test func slidersSettleOnWholeSteps() {
        #expect(SliderRow.snapped(49.9, step: FillLightPane.widthStep, in: FillLightPane.widthRange) == 48)
        #expect(SliderRow.snapped(200, step: FillLightPane.widthStep, in: FillLightPane.widthRange) == 120)
        #expect(SliderRow.snapped(0.79, step: FillLightPane.brightnessStep, in: FillLightPane.brightnessRange)
                == FillLightSettings.brightness.defaultValue)                          // 0.8 exactly: no changed dot
        #expect(SliderRow.snapped(0.01, step: FillLightPane.brightnessStep, in: FillLightPane.brightnessRange) == 0.2)
        #expect(FillLightWarmthRow.snapped(0.401) == FillLightSettings.warmth.defaultValue)
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
